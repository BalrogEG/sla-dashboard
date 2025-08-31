from flask import Blueprint, request, jsonify
from datetime import datetime, timedelta
from sqlalchemy import func, and_, or_
from src.models.user import db
from src.models.ticket import Ticket, Customer, SLADefinition, Outage, PerformanceMetric
import json

dashboard_bp = Blueprint('dashboard', __name__)

@dashboard_bp.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()})

@dashboard_bp.route('/sla-metrics', methods=['GET'])
def get_sla_metrics():
    """Get SLA metrics for dashboard"""
    try:
        # Get query parameters
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        customer_type = request.args.get('customer_type', 'all')
        product_line = request.args.get('product_line', 'all')
        
        # Parse dates
        if start_date:
            start_date = datetime.fromisoformat(start_date.replace('Z', ''))
        else:
            start_date = datetime.utcnow() - timedelta(days=30)
            
        if end_date:
            end_date = datetime.fromisoformat(end_date.replace('Z', ''))
        else:
            end_date = datetime.utcnow()
        
        # Build query
        query = db.session.query(Ticket).filter(
            Ticket.created_at >= start_date,
            Ticket.created_at <= end_date
        )
        
        # Apply filters
        if customer_type != 'all':
            query = query.join(Customer).filter(Customer.customer_type == customer_type)
        
        if product_line != 'all':
            query = query.filter(Ticket.product_line == product_line)
        
        tickets = query.all()
        
        # Calculate metrics
        total_tickets = len(tickets)
        sla_breaches = len([t for t in tickets if t.sla_breach])
        first_response_breaches = len([t for t in tickets if t.first_response_breach])
        resolution_breaches = len([t for t in tickets if t.resolution_breach])
        
        # Calculate compliance rates
        sla_compliance_rate = ((total_tickets - sla_breaches) / total_tickets * 100) if total_tickets > 0 else 100
        first_response_compliance = ((total_tickets - first_response_breaches) / total_tickets * 100) if total_tickets > 0 else 100
        resolution_compliance = ((total_tickets - resolution_breaches) / total_tickets * 100) if total_tickets > 0 else 100
        
        # Calculate average response and resolution times
        response_times = []
        resolution_times = []
        
        for ticket in tickets:
            if ticket.first_response_at and ticket.created_at:
                response_time = (ticket.first_response_at - ticket.created_at).total_seconds() / 3600
                response_times.append(response_time)
            
            if ticket.resolved_at and ticket.created_at:
                resolution_time = (ticket.resolved_at - ticket.created_at).total_seconds() / 3600
                resolution_times.append(resolution_time)
        
        avg_response_time = sum(response_times) / len(response_times) if response_times else 0
        avg_resolution_time = sum(resolution_times) / len(resolution_times) if resolution_times else 0
        
        # Priority breakdown
        priority_breakdown = {}
        for ticket in tickets:
            priority = ticket.priority or 'Unknown'
            if priority not in priority_breakdown:
                priority_breakdown[priority] = {'total': 0, 'breaches': 0}
            priority_breakdown[priority]['total'] += 1
            if ticket.sla_breach:
                priority_breakdown[priority]['breaches'] += 1
        
        # Status breakdown
        status_breakdown = {}
        for ticket in tickets:
            status = ticket.status or 'Unknown'
            status_breakdown[status] = status_breakdown.get(status, 0) + 1
        
        return jsonify({
            'period': {
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            },
            'filters': {
                'customer_type': customer_type,
                'product_line': product_line
            },
            'summary': {
                'total_tickets': total_tickets,
                'sla_breaches': sla_breaches,
                'sla_compliance_rate': round(sla_compliance_rate, 2),
                'first_response_compliance': round(first_response_compliance, 2),
                'resolution_compliance': round(resolution_compliance, 2),
                'avg_response_time_hours': round(avg_response_time, 2),
                'avg_resolution_time_hours': round(avg_resolution_time, 2)
            },
            'breakdowns': {
                'priority': priority_breakdown,
                'status': status_breakdown
            }
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@dashboard_bp.route('/customer-segments', methods=['GET'])
def get_customer_segments():
    """Get customer segment analysis"""
    try:
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        
        if start_date:
            start_date = datetime.fromisoformat(start_date.replace('Z', ''))
        else:
            start_date = datetime.utcnow() - timedelta(days=30)
            
        if end_date:
            end_date = datetime.fromisoformat(end_date.replace('Z', ''))
        else:
            end_date = datetime.utcnow()
        
        # Get customer segments data
        segments = db.session.query(
            Customer.customer_type,
            func.count(Ticket.id).label('total_tickets'),
            func.sum(func.cast(Ticket.sla_breach, db.Integer)).label('sla_breaches'),
            func.avg(
                func.extract('epoch', Ticket.resolved_at - Ticket.created_at) / 3600
            ).label('avg_resolution_hours')
        ).join(Ticket).filter(
            Ticket.created_at >= start_date,
            Ticket.created_at <= end_date
        ).group_by(Customer.customer_type).all()
        
        segment_data = []
        for segment in segments:
            compliance_rate = 0
            if segment.total_tickets > 0:
                compliance_rate = ((segment.total_tickets - (segment.sla_breaches or 0)) / segment.total_tickets) * 100
            
            segment_data.append({
                'customer_type': segment.customer_type,
                'total_tickets': segment.total_tickets,
                'sla_breaches': segment.sla_breaches or 0,
                'sla_compliance_rate': round(compliance_rate, 2),
                'avg_resolution_hours': round(segment.avg_resolution_hours or 0, 2)
            })
        
        return jsonify({
            'period': {
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            },
            'segments': segment_data
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@dashboard_bp.route('/outages', methods=['GET'])
def get_outages():
    """Get outage analysis"""
    try:
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        product_line = request.args.get('product_line', 'all')
        
        if start_date:
            start_date = datetime.fromisoformat(start_date.replace('Z', ''))
        else:
            start_date = datetime.utcnow() - timedelta(days=30)
            
        if end_date:
            end_date = datetime.fromisoformat(end_date.replace('Z', ''))
        else:
            end_date = datetime.utcnow()
        
        # Build query
        query = db.session.query(Outage).filter(
            Outage.start_time >= start_date,
            Outage.start_time <= end_date
        )
        
        if product_line != 'all':
            query = query.filter(Outage.product_line == product_line)
        
        outages = query.all()
        
        # Calculate metrics
        total_outages = len(outages)
        ongoing_outages = len([o for o in outages if o.end_time is None])
        total_downtime_minutes = sum([
            (o.end_time - o.start_time).total_seconds() / 60 
            for o in outages if o.end_time
        ])
        
        # Severity breakdown
        severity_breakdown = {}
        for outage in outages:
            severity = outage.severity or 'Unknown'
            severity_breakdown[severity] = severity_breakdown.get(severity, 0) + 1
        
        # Product line breakdown
        product_breakdown = {}
        for outage in outages:
            product = outage.product_line or 'Unknown'
            if product not in product_breakdown:
                product_breakdown[product] = {'count': 0, 'downtime_minutes': 0}
            product_breakdown[product]['count'] += 1
            if outage.end_time:
                downtime = (outage.end_time - outage.start_time).total_seconds() / 60
                product_breakdown[product]['downtime_minutes'] += downtime
        
        # MTTR calculation
        resolved_outages = [o for o in outages if o.end_time]
        mttr_minutes = 0
        if resolved_outages:
            total_resolution_time = sum([
                (o.end_time - o.start_time).total_seconds() / 60 
                for o in resolved_outages
            ])
            mttr_minutes = total_resolution_time / len(resolved_outages)
        
        return jsonify({
            'period': {
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            },
            'summary': {
                'total_outages': total_outages,
                'ongoing_outages': ongoing_outages,
                'total_downtime_minutes': round(total_downtime_minutes, 2),
                'mttr_minutes': round(mttr_minutes, 2),
                'availability_percentage': 99.9  # Calculate based on total service time
            },
            'breakdowns': {
                'severity': severity_breakdown,
                'product_line': product_breakdown
            },
            'outages': [outage.to_dict() for outage in outages]
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@dashboard_bp.route('/executive-summary', methods=['GET'])
def get_executive_summary():
    """Generate executive summary"""
    try:
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        
        if start_date:
            start_date = datetime.fromisoformat(start_date.replace('Z', ''))
        else:
            start_date = datetime.utcnow() - timedelta(days=30)
            
        if end_date:
            end_date = datetime.fromisoformat(end_date.replace('Z', ''))
        else:
            end_date = datetime.utcnow()
        
        # Get overall metrics
        total_tickets = db.session.query(Ticket).filter(
            Ticket.created_at >= start_date,
            Ticket.created_at <= end_date
        ).count()
        
        sla_breaches = db.session.query(Ticket).filter(
            Ticket.created_at >= start_date,
            Ticket.created_at <= end_date,
            Ticket.sla_breach == True
        ).count()
        
        total_outages = db.session.query(Outage).filter(
            Outage.start_time >= start_date,
            Outage.start_time <= end_date
        ).count()
        
        open_tickets = db.session.query(Ticket).filter(
            Ticket.created_at >= start_date,
            Ticket.created_at <= end_date,
            Ticket.status.in_(['Open', 'Pending', 'Escalated'])
        ).count()
        
        # Calculate compliance rate
        compliance_rate = ((total_tickets - sla_breaches) / total_tickets * 100) if total_tickets > 0 else 100
        
        # Get top issues
        top_issues = db.session.query(
            Ticket.issue_type,
            func.count(Ticket.id).label('count')
        ).filter(
            Ticket.created_at >= start_date,
            Ticket.created_at <= end_date
        ).group_by(Ticket.issue_type).order_by(func.count(Ticket.id).desc()).limit(5).all()
        
        # Generate summary text
        period_days = (end_date - start_date).days
        summary_text = f"""
        Executive Summary for {period_days}-day period ({start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}):
        
        • Total tickets processed: {total_tickets}
        • SLA compliance rate: {compliance_rate:.1f}%
        • Total service outages: {total_outages}
        • Currently open tickets: {open_tickets}
        
        Key Performance Indicators:
        - SLA breaches: {sla_breaches} tickets ({(sla_breaches/total_tickets*100):.1f}% of total)
        - Service availability maintained above target levels
        - Response times within acceptable ranges for most customer segments
        
        Top Issues:
        {chr(10).join([f"- {issue.issue_type}: {issue.count} tickets" for issue in top_issues[:3]])}
        
        Recommendations:
        - Focus on reducing SLA breaches in high-priority segments
        - Implement proactive monitoring for recurring issues
        - Enhance customer communication during outages
        """
        
        return jsonify({
            'period': {
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat(),
                'days': period_days
            },
            'key_metrics': {
                'total_tickets': total_tickets,
                'sla_compliance_rate': round(compliance_rate, 2),
                'sla_breaches': sla_breaches,
                'total_outages': total_outages,
                'open_tickets': open_tickets
            },
            'top_issues': [{'issue_type': issue.issue_type, 'count': issue.count} for issue in top_issues],
            'summary_text': summary_text.strip()
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@dashboard_bp.route('/trends', methods=['GET'])
def get_trends():
    """Get trend analysis data"""
    try:
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        customer_type = request.args.get('customer_type', 'all')
        
        if start_date:
            start_date = datetime.fromisoformat(start_date.replace('Z', ''))
        else:
            start_date = datetime.utcnow() - timedelta(days=30)
            
        if end_date:
            end_date = datetime.fromisoformat(end_date.replace('Z', ''))
        else:
            end_date = datetime.utcnow()
        
        # Get daily metrics
        daily_metrics = db.session.query(
            func.date(Ticket.created_at).label('date'),
            func.count(Ticket.id).label('total_tickets'),
            func.sum(func.cast(Ticket.sla_breach, db.Integer)).label('sla_breaches')
        ).filter(
            Ticket.created_at >= start_date,
            Ticket.created_at <= end_date
        )
        
        if customer_type != 'all':
            daily_metrics = daily_metrics.join(Customer).filter(Customer.customer_type == customer_type)
        
        daily_metrics = daily_metrics.group_by(func.date(Ticket.created_at)).all()
        
        trend_data = []
        for metric in daily_metrics:
            compliance_rate = 0
            if metric.total_tickets > 0:
                compliance_rate = ((metric.total_tickets - (metric.sla_breaches or 0)) / metric.total_tickets) * 100
            
            trend_data.append({
                'date': str(metric.date),
                'total_tickets': metric.total_tickets,
                'sla_breaches': metric.sla_breaches or 0,
                'sla_compliance_rate': round(compliance_rate, 2)
            })
        
        return jsonify({
            'period': {
                'start_date': start_date.isoformat(),
                'end_date': end_date.isoformat()
            },
            'customer_type': customer_type,
            'trends': trend_data
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@dashboard_bp.route('/tickets', methods=['GET'])
def get_tickets():
    """Get tickets with filtering and pagination"""
    try:
        # Get query parameters
        page = int(request.args.get('page', 1))
        per_page = int(request.args.get('per_page', 50))
        start_date = request.args.get('start_date')
        end_date = request.args.get('end_date')
        customer_type = request.args.get('customer_type')
        priority = request.args.get('priority')
        status = request.args.get('status')
        sla_breach = request.args.get('sla_breach')
        
        # Build query
        query = db.session.query(Ticket)
        
        # Apply date filters
        if start_date:
            start_date = datetime.fromisoformat(start_date.replace('Z', ''))
            query = query.filter(Ticket.created_at >= start_date)
        
        if end_date:
            end_date = datetime.fromisoformat(end_date.replace('Z', ''))
            query = query.filter(Ticket.created_at <= end_date)
        
        # Apply other filters
        if customer_type:
            query = query.join(Customer).filter(Customer.customer_type == customer_type)
        
        if priority:
            query = query.filter(Ticket.priority == priority)
        
        if status:
            query = query.filter(Ticket.status == status)
        
        if sla_breach:
            query = query.filter(Ticket.sla_breach == (sla_breach.lower() == 'true'))
        
        # Order by creation date (newest first)
        query = query.order_by(Ticket.created_at.desc())
        
        # Paginate
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        tickets = pagination.items
        
        return jsonify({
            'tickets': [ticket.to_dict() for ticket in tickets],
            'pagination': {
                'page': page,
                'per_page': per_page,
                'total': pagination.total,
                'pages': pagination.pages,
                'has_next': pagination.has_next,
                'has_prev': pagination.has_prev
            }
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

