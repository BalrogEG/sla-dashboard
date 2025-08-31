from src.models.user import db
from datetime import datetime
import json

class Customer(db.Model):
    __tablename__ = 'customers'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    customer_type = db.Column(db.String(50), nullable=False)  # wholesale, enterprise, local_enterprise
    sla_tier = db.Column(db.String(50))
    geography = db.Column(db.String(100))
    contact_info = db.Column(db.Text)  # JSON string
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    tickets = db.relationship('Ticket', backref='customer', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'customer_type': self.customer_type,
            'sla_tier': self.sla_tier,
            'geography': self.geography,
            'contact_info': json.loads(self.contact_info) if self.contact_info else {},
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

class Ticket(db.Model):
    __tablename__ = 'tickets'
    
    id = db.Column(db.Integer, primary_key=True)
    external_id = db.Column(db.String(100), unique=True, nullable=False)
    customer_id = db.Column(db.Integer, db.ForeignKey('customers.id'))
    product_line = db.Column(db.String(100))
    priority = db.Column(db.String(20))  # low, medium, high, critical
    status = db.Column(db.String(50))
    subject = db.Column(db.Text)
    description = db.Column(db.Text)
    issue_type = db.Column(db.String(100))
    service_type = db.Column(db.String(100))
    
    # Timestamps
    created_at = db.Column(db.DateTime, nullable=False)
    updated_at = db.Column(db.DateTime)
    resolved_at = db.Column(db.DateTime)
    first_response_at = db.Column(db.DateTime)
    
    # SLA fields
    first_response_due = db.Column(db.DateTime)
    resolution_due = db.Column(db.DateTime)
    sla_breach = db.Column(db.Boolean, default=False)
    first_response_breach = db.Column(db.Boolean, default=False)
    resolution_breach = db.Column(db.Boolean, default=False)
    
    # Additional fields
    requester_id = db.Column(db.String(100))
    tags = db.Column(db.Text)  # JSON string
    custom_fields = db.Column(db.Text)  # JSON string
    
    def to_dict(self):
        return {
            'id': self.id,
            'external_id': self.external_id,
            'customer_id': self.customer_id,
            'customer_name': self.customer.name if self.customer else 'Unknown',
            'customer_type': self.customer.customer_type if self.customer else 'Unknown',
            'product_line': self.product_line,
            'priority': self.priority,
            'status': self.status,
            'subject': self.subject,
            'description': self.description,
            'issue_type': self.issue_type,
            'service_type': self.service_type,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'resolved_at': self.resolved_at.isoformat() if self.resolved_at else None,
            'first_response_at': self.first_response_at.isoformat() if self.first_response_at else None,
            'first_response_due': self.first_response_due.isoformat() if self.first_response_due else None,
            'resolution_due': self.resolution_due.isoformat() if self.resolution_due else None,
            'sla_breach': self.sla_breach,
            'first_response_breach': self.first_response_breach,
            'resolution_breach': self.resolution_breach,
            'requester_id': self.requester_id,
            'tags': json.loads(self.tags) if self.tags else [],
            'custom_fields': json.loads(self.custom_fields) if self.custom_fields else {}
        }

class SLADefinition(db.Model):
    __tablename__ = 'sla_definitions'
    
    id = db.Column(db.Integer, primary_key=True)
    customer_type = db.Column(db.String(50), nullable=False)
    priority = db.Column(db.String(20), nullable=False)
    response_time_hours = db.Column(db.Integer, nullable=False)
    resolution_time_hours = db.Column(db.Integer, nullable=False)
    availability_percentage = db.Column(db.Float, default=99.9)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        return {
            'id': self.id,
            'customer_type': self.customer_type,
            'priority': self.priority,
            'response_time_hours': self.response_time_hours,
            'resolution_time_hours': self.resolution_time_hours,
            'availability_percentage': self.availability_percentage,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class Outage(db.Model):
    __tablename__ = 'outages'
    
    id = db.Column(db.Integer, primary_key=True)
    product_line = db.Column(db.String(100), nullable=False)
    service_type = db.Column(db.String(100))
    start_time = db.Column(db.DateTime, nullable=False)
    end_time = db.Column(db.DateTime)
    severity = db.Column(db.String(20))  # low, medium, high, critical
    affected_customers = db.Column(db.Integer, default=0)
    root_cause = db.Column(db.Text)
    resolution_summary = db.Column(db.Text)
    ticket_id = db.Column(db.Integer, db.ForeignKey('tickets.id'))
    
    # Relationships
    ticket = db.relationship('Ticket', backref='outages', lazy=True)
    
    def to_dict(self):
        duration_minutes = 0
        if self.end_time and self.start_time:
            duration_minutes = (self.end_time - self.start_time).total_seconds() / 60
        
        return {
            'id': self.id,
            'product_line': self.product_line,
            'service_type': self.service_type,
            'start_time': self.start_time.isoformat() if self.start_time else None,
            'end_time': self.end_time.isoformat() if self.end_time else None,
            'duration_minutes': duration_minutes,
            'severity': self.severity,
            'affected_customers': self.affected_customers,
            'root_cause': self.root_cause,
            'resolution_summary': self.resolution_summary,
            'ticket_id': self.ticket_id,
            'is_ongoing': self.end_time is None
        }

class PerformanceMetric(db.Model):
    __tablename__ = 'performance_metrics'
    
    id = db.Column(db.Integer, primary_key=True)
    date = db.Column(db.Date, nullable=False)
    customer_type = db.Column(db.String(50))
    product_line = db.Column(db.String(100))
    
    # SLA Metrics
    total_tickets = db.Column(db.Integer, default=0)
    sla_compliant_tickets = db.Column(db.Integer, default=0)
    sla_breach_tickets = db.Column(db.Integer, default=0)
    avg_response_time_hours = db.Column(db.Float, default=0)
    avg_resolution_time_hours = db.Column(db.Float, default=0)
    
    # Service Metrics
    availability_percentage = db.Column(db.Float, default=100)
    total_outages = db.Column(db.Integer, default=0)
    total_outage_minutes = db.Column(db.Integer, default=0)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        sla_compliance_rate = 0
        if self.total_tickets > 0:
            sla_compliance_rate = (self.sla_compliant_tickets / self.total_tickets) * 100
        
        return {
            'id': self.id,
            'date': self.date.isoformat() if self.date else None,
            'customer_type': self.customer_type,
            'product_line': self.product_line,
            'total_tickets': self.total_tickets,
            'sla_compliant_tickets': self.sla_compliant_tickets,
            'sla_breach_tickets': self.sla_breach_tickets,
            'sla_compliance_rate': round(sla_compliance_rate, 2),
            'avg_response_time_hours': round(self.avg_response_time_hours, 2),
            'avg_resolution_time_hours': round(self.avg_resolution_time_hours, 2),
            'availability_percentage': round(self.availability_percentage, 2),
            'total_outages': self.total_outages,
            'total_outage_minutes': self.total_outage_minutes,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

