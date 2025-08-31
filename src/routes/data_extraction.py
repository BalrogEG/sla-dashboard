from flask import Blueprint, request, jsonify
from datetime import datetime, timedelta
from src.models.user import db
from src.models.ticket import Ticket, Customer, SLADefinition, Outage
import json
import os

extraction_bp = Blueprint('extraction', __name__)

@extraction_bp.route('/import-freshdesk-data', methods=['POST'])
def import_freshdesk_data():
    """Import Freshdesk ticket data into the dashboard database"""
    try:
        # Load the existing Freshdesk ticket data
        data_file = '/home/ubuntu/raw_tickets_data.json'
        
        if not os.path.exists(data_file):
            return jsonify({'error': 'Freshdesk data file not found'}), 404
        
        with open(data_file, 'r') as f:
            freshdesk_tickets = json.load(f)
        
        imported_count = 0
        updated_count = 0
        
        for ticket_data in freshdesk_tickets:
            try:
                # Extract customer information
                custom_fields = ticket_data.get('custom_fields', {})
                customer_type_raw = custom_fields.get('cf_customer_type', 'Unknown')
                
                # Determine customer type
                customer_type = 'unknown'
                if 'Enterprise' in customer_type_raw:
                    if 'Egypt' in customer_type_raw or 'KSA' in customer_type_raw or 'Pakistan' in customer_type_raw:
                        customer_type = 'local_enterprise'
                    else:
                        customer_type = 'enterprise'
                elif 'Wholesale' in customer_type_raw:
                    customer_type = 'wholesale'
                elif 'Internal' in customer_type_raw:
                    customer_type = 'internal'
                
                # Extract customer name from subject
                customer_name = extract_customer_name(ticket_data.get('subject', ''))
                if not customer_name:
                    customer_name = f"Customer_{ticket_data.get('requester_id', 'Unknown')}"
                
                # Get or create customer
                customer = Customer.query.filter_by(name=customer_name).first()
                if not customer:
                    geography = 'Unknown'
                    if 'Egypt' in customer_type_raw:
                        geography = 'Egypt'
                    elif 'KSA' in customer_type_raw or 'Saudi' in customer_type_raw:
                        geography = 'KSA'
                    elif 'Pakistan' in customer_type_raw:
                        geography = 'Pakistan'
                    
                    customer = Customer(
                        name=customer_name,
                        customer_type=customer_type,
                        geography=geography,
                        sla_tier=custom_fields.get('cf_customer_tier', 'Standard'),
                        contact_info=json.dumps({'requester_id': ticket_data.get('requester_id')})
                    )
                    db.session.add(customer)
                    db.session.flush()  # Get the ID
                
                # Check if ticket already exists
                existing_ticket = Ticket.query.filter_by(external_id=str(ticket_data['id'])).first()
                
                # Parse timestamps
                created_at = datetime.fromisoformat(ticket_data['created_at'].replace('Z', '+00:00'))
                updated_at = datetime.fromisoformat(ticket_data['updated_at'].replace('Z', '+00:00'))
                
                # Determine service type and issue type
                subject = ticket_data.get('subject', '').lower()
                service_type = determine_service_type(subject, custom_fields)
                issue_type = determine_issue_type(subject)
                
                # Calculate SLA information
                priority = map_priority(ticket_data.get('priority', 2))
                sla_info = calculate_sla_info(created_at, updated_at, priority, customer_type)
                
                if existing_ticket:
                    # Update existing ticket
                    existing_ticket.customer_id = customer.id
                    existing_ticket.product_line = custom_fields.get('cf_product973573', service_type)
                    existing_ticket.priority = priority
                    existing_ticket.status = map_status(ticket_data.get('status', 2))
                    existing_ticket.subject = ticket_data.get('subject', '')
                    existing_ticket.description = clean_html(ticket_data.get('description', ''))
                    existing_ticket.issue_type = issue_type
                    existing_ticket.service_type = service_type
                    existing_ticket.updated_at = updated_at
                    existing_ticket.first_response_due = sla_info['first_response_due']
                    existing_ticket.resolution_due = sla_info['resolution_due']
                    existing_ticket.sla_breach = sla_info['sla_breach']
                    existing_ticket.first_response_breach = sla_info['first_response_breach']
                    existing_ticket.resolution_breach = sla_info['resolution_breach']
                    existing_ticket.tags = json.dumps(ticket_data.get('tags', []))
                    existing_ticket.custom_fields = json.dumps(custom_fields)
                    updated_count += 1
                else:
                    # Create new ticket
                    new_ticket = Ticket(
                        external_id=str(ticket_data['id']),
                        customer_id=customer.id,
                        product_line=custom_fields.get('cf_product973573', service_type),
                        priority=priority,
                        status=map_status(ticket_data.get('status', 2)),
                        subject=ticket_data.get('subject', ''),
                        description=clean_html(ticket_data.get('description', '')),
                        issue_type=issue_type,
                        service_type=service_type,
                        created_at=created_at,
                        updated_at=updated_at,
                        first_response_due=sla_info['first_response_due'],
                        resolution_due=sla_info['resolution_due'],
                        sla_breach=sla_info['sla_breach'],
                        first_response_breach=sla_info['first_response_breach'],
                        resolution_breach=sla_info['resolution_breach'],
                        requester_id=str(ticket_data.get('requester_id', '')),
                        tags=json.dumps(ticket_data.get('tags', [])),
                        custom_fields=json.dumps(custom_fields)
                    )
                    db.session.add(new_ticket)
                    imported_count += 1
                
                # Create outage record if it's an outage
                if is_outage_ticket(subject):
                    create_outage_record(ticket_data, service_type)
                
            except Exception as e:
                print(f"Error processing ticket {ticket_data.get('id')}: {str(e)}")
                continue
        
        # Commit all changes
        db.session.commit()
        
        # Initialize SLA definitions if they don't exist
        initialize_sla_definitions()
        
        return jsonify({
            'success': True,
            'imported_tickets': imported_count,
            'updated_tickets': updated_count,
            'total_processed': len(freshdesk_tickets)
        })
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

def extract_customer_name(subject):
    """Extract customer name from ticket subject"""
    import re
    
    # Known customer patterns
    customers = ['Biddex', 'Faysal', 'Tarabezah', 'InstaPrints', 'Intlaq', 'Majalat', 'Toobit', 'POLIGON']
    
    for customer in customers:
        if customer.lower() in subject.lower():
            return customer
    
    # Try to extract from patterns
    patterns = [
        r'(\w+)\s*\|',  # Customer name before pipe
        r'\|\s*(\w+)',  # Customer name after pipe
        r'(\w+)\s*API',  # Customer name before API
    ]
    
    for pattern in patterns:
        matches = re.findall(pattern, subject, re.IGNORECASE)
        for match in matches:
            if len(match) > 2 and match.isalpha():
                return match.title()
    
    return None

def determine_service_type(subject, custom_fields):
    """Determine service type from subject and custom fields"""
    product = custom_fields.get('cf_product973573', '')
    if product:
        return product
    
    if any(term in subject for term in ['sms', 'message', 'delivery']):
        return 'SMS'
    elif any(term in subject for term in ['voice', 'call', 'trunk', 'occ']):
        return 'OCC'
    elif any(term in subject for term in ['api', 'integration']):
        return 'API'
    else:
        return 'Other'

def determine_issue_type(subject):
    """Determine issue type from subject"""
    subject_lower = subject.lower()
    
    if any(term in subject_lower for term in ['outage', 'down', 'connection down']):
        return 'Service Outage'
    elif any(term in subject_lower for term in ['delivery', 'failed', 'not delivered']):
        return 'Delivery Issue'
    elif any(term in subject_lower for term in ['api', 'integration', 'authentication']):
        return 'API Integration'
    elif any(term in subject_lower for term in ['otp', 'verification']):
        return 'OTP Service'
    elif any(term in subject_lower for term in ['whatsapp', 'wab']):
        return 'WhatsApp Business'
    elif any(term in subject_lower for term in ['sender id', 'registration']):
        return 'Sender ID'
    elif any(term in subject_lower for term in ['billing', 'credit', 'payment']):
        return 'Account/Billing'
    elif any(term in subject_lower for term in ['performance', 'slow', 'cpu']):
        return 'Performance'
    else:
        return 'General Support'

def map_priority(priority_code):
    """Map Freshdesk priority code to string"""
    priority_map = {1: 'Low', 2: 'Medium', 3: 'High', 4: 'Critical'}
    return priority_map.get(priority_code, 'Medium')

def map_status(status_code):
    """Map Freshdesk status code to string"""
    status_map = {
        2: 'Open', 3: 'Pending', 4: 'Resolved', 5: 'Closed',
        6: 'Waiting on Customer', 7: 'Waiting on Third Party', 16: 'Escalated'
    }
    return status_map.get(status_code, 'Open')

def calculate_sla_info(created_at, updated_at, priority, customer_type):
    """Calculate SLA information for a ticket"""
    # SLA targets based on priority and customer type
    sla_targets = {
        'enterprise': {
            'Critical': {'response': 1, 'resolution': 4},
            'High': {'response': 2, 'resolution': 8},
            'Medium': {'response': 4, 'resolution': 24},
            'Low': {'response': 8, 'resolution': 72}
        },
        'local_enterprise': {
            'Critical': {'response': 1, 'resolution': 4},
            'High': {'response': 2, 'resolution': 8},
            'Medium': {'response': 4, 'resolution': 24},
            'Low': {'response': 8, 'resolution': 72}
        },
        'wholesale': {
            'Critical': {'response': 2, 'resolution': 8},
            'High': {'response': 4, 'resolution': 12},
            'Medium': {'response': 8, 'resolution': 48},
            'Low': {'response': 12, 'resolution': 96}
        }
    }
    
    targets = sla_targets.get(customer_type, sla_targets['enterprise'])
    target = targets.get(priority, targets['Medium'])
    
    # Calculate due times
    first_response_due = created_at + timedelta(hours=target['response'])
    resolution_due = created_at + timedelta(hours=target['resolution'])
    
    # Check for breaches (simplified - assumes first update is first response)
    current_time = datetime.utcnow().replace(tzinfo=created_at.tzinfo)
    
    first_response_breach = updated_at > first_response_due if updated_at != created_at else current_time > first_response_due
    resolution_breach = current_time > resolution_due  # Simplified - should check if resolved
    
    sla_breach = first_response_breach or resolution_breach
    
    return {
        'first_response_due': first_response_due,
        'resolution_due': resolution_due,
        'sla_breach': sla_breach,
        'first_response_breach': first_response_breach,
        'resolution_breach': resolution_breach
    }

def clean_html(text):
    """Remove HTML tags from text"""
    import re
    if not text:
        return ''
    
    # Remove HTML tags
    clean = re.sub('<.*?>', '', text)
    # Remove extra whitespace
    clean = ' '.join(clean.split())
    return clean[:500]  # Limit length

def is_outage_ticket(subject):
    """Check if ticket represents an outage"""
    outage_indicators = ['outage', 'down', 'connection down', 'triggered:', 'no data:', 'service interruption']
    return any(indicator in subject.lower() for indicator in outage_indicators)

def create_outage_record(ticket_data, service_type):
    """Create an outage record from ticket data"""
    subject = ticket_data.get('subject', '')
    created_at = datetime.fromisoformat(ticket_data['created_at'].replace('Z', '+00:00'))
    
    # Determine severity from priority
    priority = ticket_data.get('priority', 2)
    severity_map = {1: 'Low', 2: 'Medium', 3: 'High', 4: 'Critical'}
    severity = severity_map.get(priority, 'Medium')
    
    # Check if outage already exists
    existing_outage = Outage.query.filter_by(
        ticket_id=ticket_data['id']
    ).first()
    
    if not existing_outage:
        outage = Outage(
            product_line=service_type,
            service_type=service_type,
            start_time=created_at,
            severity=severity,
            root_cause=clean_html(ticket_data.get('description', '')),
            ticket_id=ticket_data['id']
        )
        
        # If it's a recovery ticket, try to find the corresponding trigger
        if 'recovered:' in subject.lower():
            outage.end_time = created_at
        
        db.session.add(outage)

def initialize_sla_definitions():
    """Initialize SLA definitions if they don't exist"""
    sla_definitions = [
        # Enterprise SLAs
        {'customer_type': 'enterprise', 'priority': 'Critical', 'response_time_hours': 1, 'resolution_time_hours': 4},
        {'customer_type': 'enterprise', 'priority': 'High', 'response_time_hours': 2, 'resolution_time_hours': 8},
        {'customer_type': 'enterprise', 'priority': 'Medium', 'response_time_hours': 4, 'resolution_time_hours': 24},
        {'customer_type': 'enterprise', 'priority': 'Low', 'response_time_hours': 8, 'resolution_time_hours': 72},
        
        # Local Enterprise SLAs (same as enterprise)
        {'customer_type': 'local_enterprise', 'priority': 'Critical', 'response_time_hours': 1, 'resolution_time_hours': 4},
        {'customer_type': 'local_enterprise', 'priority': 'High', 'response_time_hours': 2, 'resolution_time_hours': 8},
        {'customer_type': 'local_enterprise', 'priority': 'Medium', 'response_time_hours': 4, 'resolution_time_hours': 24},
        {'customer_type': 'local_enterprise', 'priority': 'Low', 'response_time_hours': 8, 'resolution_time_hours': 72},
        
        # Wholesale SLAs (more relaxed)
        {'customer_type': 'wholesale', 'priority': 'Critical', 'response_time_hours': 2, 'resolution_time_hours': 8},
        {'customer_type': 'wholesale', 'priority': 'High', 'response_time_hours': 4, 'resolution_time_hours': 12},
        {'customer_type': 'wholesale', 'priority': 'Medium', 'response_time_hours': 8, 'resolution_time_hours': 48},
        {'customer_type': 'wholesale', 'priority': 'Low', 'response_time_hours': 12, 'resolution_time_hours': 96},
    ]
    
    for sla_def in sla_definitions:
        existing = SLADefinition.query.filter_by(
            customer_type=sla_def['customer_type'],
            priority=sla_def['priority']
        ).first()
        
        if not existing:
            sla = SLADefinition(**sla_def)
            db.session.add(sla)
    
    db.session.commit()

@extraction_bp.route('/sla-definitions', methods=['GET'])
def get_sla_definitions():
    """Get all SLA definitions"""
    try:
        sla_definitions = SLADefinition.query.all()
        return jsonify({
            'sla_definitions': [sla.to_dict() for sla in sla_definitions]
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@extraction_bp.route('/customers', methods=['GET'])
def get_customers():
    """Get all customers"""
    try:
        customers = Customer.query.all()
        return jsonify({
            'customers': [customer.to_dict() for customer in customers]
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

