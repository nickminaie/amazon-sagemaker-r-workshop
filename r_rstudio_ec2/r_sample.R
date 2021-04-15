"
This code demonstrates how to train, deploy, and retrieve predictions from a
machine learning (ML) model using Amazon SageMaker and R. The model predicts abalone
age as measured by the number of rings in the shell.

The reticulate package will be used as an R interface to Amazon SageMaker Python SDK to
make API calls to Amazon SageMaker. The reticulate package translates between R and
Python objects, and Amazon SageMaker provides a serverless data science environment
to train and deploy ML models at scale.
"

# Import reticulate library
library(reticulate)

# Install miniconda environment before conda_install
install_miniconda()

# Install packages
conda_install(envname = "r-reticulate", packages="sagemaker-python-sdk")
conda_install(packages="pandas")

# Import libraries and packages
library(readr)
library(dplyr)
library(stringr)
library(ggplot2)
sagemaker <- import('sagemaker')

# Set up the SageMaker Environment
session <- sagemaker$Session()
bucket <- session$default_bucket()
role_arn <- session$expand_role(role='sagemaker-service-role')

# Downloan Abalone Data from UCI
data_file <- 'http://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data'
abalone <- read_csv(file = data_file, col_names = FALSE)
names(abalone) <- c('sex', 'length', 'diameter', 'height', 'whole_weight', 'shucked_weight', 'viscera_weight', 'shell_weight', 'rings')
head(abalone)

# Convert Sex to factor becasue Sex is a Char datatype and as M and F should be factor
abalone$sex <- as.factor(abalone$sex)
head(abalone)
# The summary shows that the minimum value for height is 0
summary(abalone)

# Visually explore which abalones have height equal to 0 by plotting the relationship
# between rings and height for each value of sex
ggplot(abalone, aes(x = height, y = rings, color = sex)) + geom_point() + geom_jitter()

# Filter out the abalones with a height of 0
abalone <- abalone %>%
  filter(height != 0)

### PREPARING THE DATASET FOR MODEL TRAINING
# One Hot Encode 'sex' column and remove 'sex'
abalone <- abalone %>%
  mutate(female = as.integer(ifelse(sex == 'F', 1, 0)),
         male = as.integer(ifelse(sex == 'M', 1, 0)),
         infant = as.integer(ifelse(sex == 'I', 1, 0))) %>%
  select(-sex)

# Re-organize the dataframe, put rings:infant before length:shell_weight
abalone <- abalone %>%
  select(rings:infant, length:shell_weight)
head(abalone)

# Sample 70% of the data for training the ML algorithm. Split the remaining
# 30% into two halves, one for testing and one for validation
abalone_train <- abalone %>%
  sample_frac(size = 0.7)
abalone <- anti_join(abalone, abalone_train)
abalone_test <- abalone %>%
  sample_frac(size = 0.5)
abalone_valid <- anti_join(abalone, abalone_test)

# Write train and test dataframes as CSV locally
write_csv(abalone_train, 'abalone_train.csv', col_names = FALSE)
write_csv(abalone_valid, 'abalone_valid.csv', col_names = FALSE)

# Wrie local CSV files to S3 bucket
s3_train <- session$upload_data(path = 'abalone_train.csv',
                                bucket = bucket,
                                key_prefix = 'data')
s3_valid <- session$upload_data(path = 'abalone_valid.csv',
                                bucket = bucket,
                                key_prefix = 'data')

# Define the location Sagemaker input for train and validation on S3
s3_train_input <- sagemaker$s3_input(s3_data = s3_train,
                                     content_type = 'csv')
s3_valid_input <- sagemaker$s3_input(s3_data = s3_valid,
                                     content_type = 'csv')

### TRAINING A MODEL
# Get the container registery for XGBoost docker container
registry <- sagemaker$amazon$amazon_estimator$registry(session$boto_region_name, algorithm='xgboost')
container <- paste(registry, '/xgboost:latest', sep='')

# S3 output address
s3_output <- paste0('s3://', bucket, '/output')

# Create a SageMaker Estimator
# Note – The equivalent to None in Python is NULL in R.
estimator <- sagemaker$estimator$Estimator(image_name = container,
                                           role = role_arn,
                                           train_instance_count = 1L,
                                           train_instance_type = 'ml.m5.large',
                                           train_volume_size = 30L,
                                           train_max_run = 3600L,
                                           input_mode = 'File',
                                           output_path = s3_output,
                                           output_kms_key = NULL,
                                           base_job_name = NULL,
                                           sagemaker_session = NULL)


# Set the Hyperparameters for XGBoost Estimator
estimator$set_hyperparameters(num_round = 100L)

# Create a job name
job_name <- paste('sagemaker-train-xgboost', format(Sys.time(), '%H-%M-%S'), sep = '-')

# Define the input data config for train and validation channels
input_data <- list('train' = s3_train_input,
                   'validation' = s3_valid_input)

# Train (fit) the estimator on train and validate on validation data
# This will take a couple of mins to spawn an instance, download the data from S3 to the instance
# Train and then upload the data to S3 from the instance
# At the end, it will repor the training time which is the billable time
estimator$fit(inputs = input_data,
              job_name = job_name)

# Get the location of the trained tar ball model on S3
estimator$model_data

### DEPLOY THE MODEL TO AN ENDPOINT
# This will take a few mins
model_endpoint <- estimator$deploy(initial_instance_count = 1L,
                                   instance_type = 'ml.t2.medium')

### GENERATE PREDICTIONS USING THE MODEL

# Define the endpoint serializers
# Pass comma-separated text to be serialized into JSON format
# by specifying text/csv and csv_serializer for the endpoint
model_endpoint$content_type <- 'text/csv'
model_endpoint$serializer <- sagemaker$predictor$csv_serializer

# Use the test data to generate predictions
# Remove the target column and convert the first 500 observations
# to a matrix with no column names
# Note – 500 observations was chosen because it doesn’t exceed the endpoint limitation.
abalone_test <- abalone_test[-1]
num_predict_rows <- 500
test_sample <- as.matrix(abalone_test[1:num_predict_rows, ])
dimnames(test_sample)[[2]] <- NULL

# Generate predictions from the endpoint and convert the returned comma-separated string
predictions <- model_endpoint$predict(test_sample)
predictions <- str_split(predictions, pattern = ',', simplify = TRUE)
predictions <- as.numeric(predictions)

# Column-bind the predicted rings to the test data
abalone_test <- cbind(predicted_rings = predictions,
                      abalone_test[1:num_predict_rows, ])
head(abalone_test)

# DELETE ENDPOINT
session$delete_endpoint(model_endpoint$endpoint)
