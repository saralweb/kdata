# kdata
data extraction and analysis project

Setup:
------

at the same path level, clone the following repositories

git clone https://github.com/CSSEGISandData/2019-nCoV.git

git clone https://github.com/saralweb/kdata.git


Then create database "corona" and use schema under sql/schema_2020_07_22.sql to create its structure

Now go to jhu sub-directory and issue these commands

./pulldata

./loadnext

You will see that pulldata pulls all the daily snapshot files from the jhu repository

loadnext loads just one day at a time after determining the last day loaded

You will need to run loadnext many times, until you catch up. 

The automation of these steps is work in progress and will be documented here as soon as available


