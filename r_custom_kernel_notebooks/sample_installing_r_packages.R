## Sample Code for Installing R Packages from Different Sources

## Script: Nick Minaie
## Github: https://github.com/nickminaie/AWS-SageMaker-R-Workshop
## Date: May 5, 2020


### Conda Installs, This will take a while, please be patient
### -----------------------------------------------------------------

## Conda-Forge Channel
system("conda install -n R -c conda-forge r-xgboost r-rjava")

## R Channel
system("conda install -n R -c r r-implyr")

### Installing from CRAN, This will take a while, please be patient
### -----------------------------------------------------------------
install.packages(c('textmineR'), repo = 'http://cran.rstudio.com')
