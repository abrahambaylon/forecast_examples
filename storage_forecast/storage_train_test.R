library(forecast)
library(zoo)
library(xts)
library(timeSeries)
library(ggfortify)
library(XLConnect)
library(dplyr)
library(lubridate)
library(tseries)

# set capacity and threshold
capacity=370000
pct_threshold=80
pct_train=85

# my function to set current directory
set_current_directory()

# load excel data 
# workbook <- loadWorkbook("storage.xlsx")
workbook <- loadWorkbook("storage_outliers.xlsx")

# load data
xdata <- readWorksheet(workbook, sheet = "Sheet1", header = TRUE)
xdata$Date <- as.POSIXct(xdata$Source, format="%Y-%m-%d/%H:%M:%S")
xdata2 <- zoo(xdata$Value, xdata$Date)
xdata3 <- ts(xdata2)

# explore and validate data
autoplot(xdata2)  # graph data
tsdisplay(xdata3) # check seasonality and autocorrelation of main series 
tsdisplay(diff(xdata3, lag=1)) # check seasonality and autocorrelation diff'd series
xdata4 <- ts(xdata$Value, start=c(2016,01),frequency = 365/60) # hack frequency to get decompose to run
autoplot(decompose(xdata4)) # only check remainder/random/error and trend, seasonal data is bogus/hacked
plot(decompose((decompose(xdata4)$random))) # even the error has a trend
xdata5 <- decompose(xdata4)
plot(xdata5$random)
plot(decompose(xdata5$random)) # see trend on error
plot(diff(xdata5$random,lag=1))
plot(decompose(diff(xdata5$random,lag=1))) # remove trend on error

# save new data to excel sheet
writeWorksheet (workbook, data=xdata, sheet="Sheet1", header = TRUE)
saveWorkbook(workbook, file = "storage2.xlsx")

# create test/validation sets
train <- window(xdata3, end=tsp(xdata3)[2]-round( tsp(xdata3)[2]*((100-pct_train)/100) ) )
validation <- window(xdata3, start=tsp(xdata3)[2]-round( tsp(xdata3)[2]*((100-pct_train)/100) )+1)
plot(append(train,validation))
lines(train,col="red")
lines(validation,col="blue")
xdata3 <- train  # use train set data

# generate forecast
# e <- ets(xdata3) 
# e <- rollmean(xdata3, k = 12, align = "right")
# rma <- rollmean(xdata3, k = 12, align = "right")
# e <- tslm(rma ~ trend + I(trend^2) + I(sin(2*pi*trend/12)) + I(cos(2*pi*trend/12)))
e <- tslm(xdata3 ~ trend + I(trend^2) + I(sin(2*pi*trend/12)) + I(cos(2*pi*trend/12)))
f <- forecast(e,h=length(xdata3), level=FALSE)
autoplot(f)

# add timestamp and other column measures
# GB <- append(xdata$Value,f$mean)
GB <- append(coredata(xdata3),f$mean)
# Time <- seq(as.Date(min(xdata$Date)), by = "days", length = length(xdata3)*2)  # create seq of days
Time <- seq(min(xdata$Date), by = "hours", length = length(xdata3)*2) # create seq of hours
forecast_data <- data.frame(Time,GB)
forecast_data_threshold <- tail(subset(forecast_data, forecast_data$GB > capacity*((pct_threshold-1)/100) & forecast_data$GB < capacity*(pct_threshold/100) ),n=1)
forecast_data$diff <- rbind(0, diff(as.ts(forecast_data[2])) )
forecast_data$diff_pct <- rbind(0, diff(as.ts(forecast_data[2])) / as.ts(forecast_data[2])[-nrow(as.ts(forecast_data[2])),] * 100)

# plot percentage increase
par(mfrow=c(2, 1))
plot(forecast_data$Time,abs(forecast_data$diff), type='l', cex.axis=.6, xlab = 'Time', ylab = 'diff GB')
plot(forecast_data$Time,abs(forecast_data$diff_pct), type='l', cex.axis=.6, xlab = 'Time', ylab = 'diff_pct')

# plot forecast
par(mfrow=c(1, 1))
options(scipen=10)
plot(forecast_data$Time,forecast_data$GB, main=paste0("Storage (", month(min(xdata$Date),label=TRUE,abbr=FALSE),")"), ylim=c(0,capacity*2),las=2,cex.axis=.6, xlab = 'Time', ylab = 'GB')
# axis(1, 1:length(xdata3)*2,  cex.axis = .7)   # just number index on x axis
abline(h=capacity, col="red", lty=2)
abline(h=as.numeric(forecast_data_threshold[2]), col="orange", lty=2)
abline(v=max(xdata$Date), col="blue")
legend("topleft",
       legend=c(
         paste0("(Start Day ", as.Date(min(xdata$Date)) ,")"),
         paste0("Current Day ", as.Date(max(xdata$Date))), 
         paste0("Capacity (", capacity, "GB)"), 
         paste0(pct_threshold,"% on ",as.character(format(forecast_data_threshold[1],"%Y-%m-%d")), " (", as.character(as.Date(as.character(format(forecast_data_threshold[1],"%Y-%m-%d"))) - as.Date(max(xdata$Date)))," days)" )
       ),
       col=c("","blue","red","orange"), 
       lty=c(0,1,2,2),  
       pt.cex=1, 
       cex=.5)

# get accuracy
accuracy(f,validation) 


