
from flask_sqlalchemy import SQLAlchemy
db = SQLAlchemy(app)


class Service(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    service_name = db.Column(db.String(80), unique=True)
    success = db.Column(db.Boolean(), unique=False)
    message = db.Column(db.String(256), unique=False)
    time = db.Column(db.TIMESTAMP(), unique=False)
    
    def __init__(self, service_name, success, message):
        self.service_name = service_name
        self.success = success
        self.message = message
        
    def __repr__(self):
        return '<Service name %r>' % self.service_name
    