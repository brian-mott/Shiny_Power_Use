# R Shiny App for Tracking Power Usage

Lots of graphs to show power usage over time.
Finest resolution down to the hour for kwh use, cost, and temp

Live example: https://bmott.shinyapps.io/power_use_app/

R file contains the Shiny app, python file contains a script to create sqlite db and update with 
csv values.

## Db Format:

The electricity table contains all the power usage data and the billperiod table contains information provided on each power bill. There is an inner join done to tie some of the graphs together so billperiod at least needs id, startdate, and enddate values over a time period that covers the data in order for graphs to work correctly.

If you don't want to manually enter bill period data, the billperiod_check() method of the Database class will check for data in the electricity table and then create a bill period that spans the date range of the electricity data

### electricity table: 
Data of power use, cost, and temp for 1 hour time chunks. 

- id: primary key
- timepoint: datetime of observation
- cost: decimal(4, 2) of cost for the hour
- kwh: decimal(4, 2) of kwh usage for the hour
- temp: integer of temp

### billperiod table:

Required items: need these over range of data to get graphs properly inner joined
If you don't want to enter bill periods manually, the billperiod_check() method will create
a bill period from the earliest and latest dates in the data

- id: primary key
- startdate: datetime start date for billing period. I use 00:00:00 on this date for the time value
- enddate: datetime end date of billing period. I use 23:00:00 for time on this date

Non-required items: can use or not for your own tracking pleasure

- duedate: datetime for bill due date
- paiddate: datetime for paid date
- billamount: decimal(6, 2) for bill amount

The next several items probably vary on the power provider:

- servicecost: decimal(6, 2) for amount
- environmentalcost: decimal(6, 2) for amount
- nukeconstructioncost: decimal(6, 2) for amount
- municipalfee: decimal(6, 2) for amount
- salestax: decimal(6, 2) for amount
- metercurrent: integer for meter reading
- meterprevious: integer for meter reading
- kwh: integer, total kwh for the billing period

The Database class has a basic insert_csv() method to insert a csv file of data into the electricity table. I get xlsx files with datetime, temp, and cost or kwh that I can then combine into one csv file.


## How To Setup Your Own Power Tracking:

1.  Have data available in csv format with hourly power usage in kwh, cost, and recorded temp

2.  Set database name and location parameter for the Database() instance

3.  Pass csv file to db.insert_csv() method

4.  Run create_db.py

5.  Edit billperiod table to have at least startdate and enddate periods over the range of electricity table data OR run
billperiod_check() method to create a bill period that spans the electricity data range.

6.  In R file, set db.file to same name and location as the db file in create_db.py

7.  Run PowerApp.R

8.  Press 'Load DB Data' button in the app to load data and then play around with the various graphs


In the future, I might add further automation to get new data from the power company website, update billing periods, and update the database. 