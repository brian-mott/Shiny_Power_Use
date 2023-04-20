"""
Script to create sqlite db for storing data

See readme for info on db schema and how to best import your own data
"""

from sqlalchemy import create_engine, MetaData, Table, Column, Integer, DECIMAL, DATE, DATETIME
from sqlalchemy import insert, select, bindparam
from datetime import timedelta
import pandas as pd


class Database:
    """
    Class to initially create sqlite db file and then with methods to update and upload info

    billperiods table can be filled out with various items per power bill to track some of them over time
    electricty table contains main data to graph and track, will have methods to update
    """

    def __init__(self, dbfile, echo=True):
        self.db = dbfile
        # can easily change echo if want it off
        self.echo = echo

        self.engine = create_engine(f'sqlite:///{self.db}', echo=self.echo)
        self.meta = MetaData()

        # create tables
        self.bill_periods_table = Table(
            'billperiods', self.meta,
            Column('id', Integer, primary_key=True),
            Column('startdate', DATETIME),
            Column('enddate', DATETIME),
            Column('duedate', DATE),
            Column('paiddate', DATE),
            Column('billamount', DECIMAL(6, 2)),
            Column('servicecost', DECIMAL(6, 2)),
            Column('environmentalcost', DECIMAL(6, 2)),
            Column('nukeconstructcost', DECIMAL(6, 2)),
            Column('municipalfee', DECIMAL(6, 2)),
            Column('salestax', DECIMAL(6, 2)),
            Column('metercurrent', Integer),
            Column('meterprevious', Integer),
            Column('kwh', Integer),
        )

        self.electricity_table = Table(
            'electricity', self.meta,
            Column('id', Integer, primary_key=True),
            Column('timepoint', DATETIME),
            Column('cost', DECIMAL(4, 2)),
            Column('kwh', DECIMAL(4, 2)),
            Column('temp', Integer),
        )

        # create tables if they do not already exist
        self.meta.create_all(self.engine)


    def insert_csv(self, file):
        """Inserts csv file into db, based off of heading from website download"""
        with open(file, 'r') as f:
            # specifiy name of datetime column to parse dates
            df = pd.read_csv(file, parse_dates=['Hour'])
        
        row_dict = df.to_dict('records')

        with self.engine.connect() as conn:
            conn.execute(
                insert(self.electricity_table)
                .values(
                # bind electricity columns to csv header
                    timepoint=bindparam('Hour'),
                    cost=bindparam('Cost'),
                    kwh=bindparam('kWh'),
                    temp=bindparam('Temp'),
                ),
                row_dict
            )
            conn.commit()
    

    def billperiod_check(self):
        """Method to check if billperiod table is empty and if so, to fill in values to cover date range of data"""
        # make sure there is data present in the electricity table
        with self.engine.connect() as conn:
            result = conn.execute(select(self.electricity_table))
            check = result.first()
        
        if check is None:
            raise ValueError('Please add data to the electricity table')
        
        # query table to see if empty
        with self.engine.connect() as conn:
            result = conn.execute(select(self.bill_periods_table))
            check = result.first()
        
        if check is None:
            with self.engine.connect() as conn:
                result = conn.execute(select(self.electricity_table.c.timepoint))
                result = result.all()

            # get min and max date
            min_date = min(result)
            max_date = max(result)

            # add seconds to complete hh:mm:ss format
            min_date = min_date[0] + timedelta(seconds=0)
            max_date = max_date[0] + timedelta(seconds=0)

            # add entry to billperiod to cover this range
            with self.engine.connect() as conn:
                conn.execute(
                    insert(self.bill_periods_table)
                    .values(startdate=min_date, enddate=max_date)
                )
                conn.commit()
            
            print('Added min and max dates to billperiod table')
        
        else:
            print('billperiod already contains data, nothing added')



# set db file name and location
db_file = 'data.db'

# set csv file name and location
csv_file = 'csv/sample_electricity_data.csv'


if __name__ == '__main__':
    db = Database(db_file)

    # run method to add data to electicity
    db.insert_csv(csv_file)

    # run method to automatically add billperiod date ranges from electricity data
    db.billperiod_check()

