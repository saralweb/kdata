# kdata
data extraction and analysis project

Pre-requisites
--------------
nodejs 10.15.0 +
postgresql 11.2 +
plv8 2.3.11 +
git 2.19.1 +

Developed and tested on Fedora Linux 27 64 bit

Setup:
------

at the same path level, clone the following repositories

git clone https://github.com/CSSEGISandData/2019-nCoV.git

git clone https://github.com/saralweb/kdata.git

Then create database "corona" and use schema under sql/schema_2020_07_22.sql to create its structure

-------------

cd kdata

npm install

JHU extraction 

cd jhu

./pulldata

./loadnext

cd ../

pulldata pulls all the daily snapshot files from the jhu repository

loadnext loads just one day at a time after determining the last day loaded

You will need to run loadnext many times, until you catch up. 

Covid19India extraction

cd ctind

./pullts

./loadts

cd ../

loadts is naive, it drops all ctind data and reloads from latest pull.

Analysis

cd src/js

node dumpts.js

cd ../../

cd src/sql

psql -U postgres corona < icfr_dump.sql

cd ../../



The automation of these steps is work in progress and will be documented here as soon as available


