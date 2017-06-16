
# 
#
# using debian here, alpine has problems with mysql dependencies

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
import MySQLdb

from sqlalchemy import create_engine
from sqlalchemy_utils import database_exists, create_database


import db from model_service


user_name=
user_password=

root_password=



app = Flask(__name__)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql://%s:%s@mms-mysql/services' % (user_name, user_password)





        
        
        
engine = create_engine(app.config['SQLALCHEMY_DATABASE_URI'])
if not database_exists(engine.url):
    su_engine=create_engine('mysql://root:%s@mms-mysql/services' % (root_password))
    sSQL = "GRANT ALL PRIVILEGES ON service_status.* TO 'mgrast'@'%%';"
    su_engine.execute(sSQL)
    create_database(su_engine.url)


        
        
db.create_all()

x=Service("Database", True, "some text")

db.session.add(x)

db.session.commit()

services = Service.query.all()
for s in services:
    print(s.service_name)
