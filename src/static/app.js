// SLA Dashboard Application
class SLADashboard {
    constructor() {
        this.currentSection = 'overview';
        this.currentFilters = {
            startDate: null,
            endDate: null,
            customerType: 'all'
        };
        this.charts = {};
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.setDefaultDates();
        this.loadSection('overview');
        this.checkDataImportStatus();
    }

    setupEventListeners() {
        // Navigation
        document.querySelectorAll('.sidebar .nav-link').forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const section = e.target.closest('.nav-link').dataset.section;
                this.loadSection(section);
            });
        });

        // Date inputs
        document.getElementById('startDate').addEventListener('change', () => {
            this.currentFilters.startDate = document.getElementById('startDate').value;
        });

        document.getElementById('endDate').addEventListener('change', () => {
            this.currentFilters.endDate = document.getElementById('endDate').value;
        });

        document.getElementById('customerType').addEventListener('change', () => {
            this.currentFilters.customerType = document.getElementById('customerType').value;
        });
    }

    setDefaultDates() {
        const endDate = new Date();
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - 30);

        document.getElementById('startDate').value = startDate.toISOString().split('T')[0];
        document.getElementById('endDate').value = endDate.toISOString().split('T')[0];

        this.currentFilters.startDate = startDate.toISOString().split('T')[0];
        this.currentFilters.endDate = endDate.toISOString().split('T')[0];
    }

    async checkDataImportStatus() {
        try {
            const response = await fetch('/api/dashboard/health');
            if (!response.ok) {
                this.showDataImportPrompt();
            }
        } catch (error) {
            console.error('Error checking data import status:', error);
            this.showDataImportPrompt();
        }
    }

    showDataImportPrompt() {
        const contentArea = document.getElementById('content-area');
        contentArea.innerHTML = `
            <div class="alert alert-info">
                <h4><i class="fas fa-info-circle me-2"></i>Data Import Required</h4>
                <p>No ticket data found. Please import Freshdesk data to begin using the dashboard.</p>
                <button class="btn btn-primary" onclick="dashboard.importFreshdeskData()">
                    <i class="fas fa-upload me-2"></i>Import Freshdesk Data
                </button>
            </div>
        `;
    }

    async importFreshdeskData() {
        try {
            this.showLoading('Importing Freshdesk data...');
            
            const response = await fetch('/api/extraction/import-freshdesk-data', {
                method: 'POST'
            });
            
            const result = await response.json();
            
            if (response.ok) {
                this.showSuccess(`Data imported successfully! ${result.imported_tickets} new tickets, ${result.updated_tickets} updated tickets.`);
                setTimeout(() => {
                    this.loadSection('overview');
                }, 2000);
            } else {
                this.showError(`Import failed: ${result.error}`);
            }
        } catch (error) {
            this.showError(`Import failed: ${error.message}`);
        }
    }

    loadSection(section) {
        // Update navigation
        document.querySelectorAll('.sidebar .nav-link').forEach(link => {
            link.classList.remove('active');
        });
        document.querySelector(`[data-section="${section}"]`).classList.add('active');

        this.currentSection = section;

        // Load section content
        switch (section) {
            case 'overview':
                this.loadOverview();
                break;
            case 'wholesale':
                this.loadCustomerSegment('wholesale');
                break;
            case 'enterprise':
                this.loadCustomerSegment('enterprise');
                break;
            case 'local-enterprise':
                this.loadCustomerSegment('local_enterprise');
                break;
            case 'outages':
                this.loadOutages();
                break;
            case 'executive':
                this.loadExecutiveSummary();
                break;
            case 'data-management':
                this.loadDataManagement();
                break;
        }
    }

    async loadOverview() {
        this.showLoading();
        
        try {
            const [metricsResponse, segmentsResponse, trendsResponse] = await Promise.all([
                fetch(this.buildApiUrl('/api/dashboard/sla-metrics')),
                fetch(this.buildApiUrl('/api/dashboard/customer-segments')),
                fetch(this.buildApiUrl('/api/dashboard/trends'))
            ]);

            const metrics = await metricsResponse.json();
            const segments = await segmentsResponse.json();
            const trends = await trendsResponse.json();

            this.renderOverview(metrics, segments, trends);
        } catch (error) {
            this.showError('Failed to load overview data');
        }
    }

    renderOverview(metrics, segments, trends) {
        const contentArea = document.getElementById('content-area');
        
        contentArea.innerHTML = `
            <!-- Key Metrics -->
            <div class="row mb-4">
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-primary">${metrics.summary.total_tickets}</div>
                        <div class="metric-label">Total Tickets</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value ${metrics.summary.sla_compliance_rate >= 95 ? 'text-success' : 'text-danger'}">${metrics.summary.sla_compliance_rate}%</div>
                        <div class="metric-label">SLA Compliance</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-info">${metrics.summary.avg_response_time_hours}h</div>
                        <div class="metric-label">Avg Response Time</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-warning">${metrics.summary.sla_breaches}</div>
                        <div class="metric-label">SLA Breaches</div>
                    </div>
                </div>
            </div>

            <!-- Charts Row -->
            <div class="row">
                <div class="col-md-8">
                    <div class="chart-container">
                        <h5>SLA Compliance Trend</h5>
                        <canvas id="complianceTrendChart"></canvas>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="chart-container">
                        <h5>Priority Breakdown</h5>
                        <canvas id="priorityChart"></canvas>
                    </div>
                </div>
            </div>

            <!-- Customer Segments -->
            <div class="row">
                <div class="col-12">
                    <div class="chart-container">
                        <h5>Customer Segment Performance</h5>
                        <div class="table-responsive">
                            <table class="table table-striped">
                                <thead>
                                    <tr>
                                        <th>Customer Type</th>
                                        <th>Total Tickets</th>
                                        <th>SLA Breaches</th>
                                        <th>Compliance Rate</th>
                                        <th>Avg Resolution Time</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${segments.segments.map(segment => `
                                        <tr>
                                            <td><span class="badge bg-primary">${segment.customer_type}</span></td>
                                            <td>${segment.total_tickets}</td>
                                            <td>${segment.sla_breaches}</td>
                                            <td>
                                                <span class="status-badge ${segment.sla_compliance_rate >= 95 ? 'status-compliant' : 'status-breach'}">
                                                    ${segment.sla_compliance_rate}%
                                                </span>
                                            </td>
                                            <td>${segment.avg_resolution_hours}h</td>
                                        </tr>
                                    `).join('')}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Render charts
        this.renderComplianceTrendChart(trends.trends);
        this.renderPriorityChart(metrics.breakdowns.priority);
    }

    async loadCustomerSegment(customerType) {
        this.showLoading();
        
        try {
            const response = await fetch(this.buildApiUrl('/api/dashboard/sla-metrics', { customer_type: customerType }));
            const data = await response.json();
            
            this.renderCustomerSegment(customerType, data);
        } catch (error) {
            this.showError(`Failed to load ${customerType} data`);
        }
    }

    renderCustomerSegment(customerType, data) {
        const contentArea = document.getElementById('content-area');
        const title = customerType.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase());
        
        contentArea.innerHTML = `
            <div class="row mb-4">
                <div class="col-12">
                    <h3>${title} Customer Performance</h3>
                </div>
            </div>

            <!-- Key Metrics -->
            <div class="row mb-4">
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-primary">${data.summary.total_tickets}</div>
                        <div class="metric-label">Total Tickets</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value ${data.summary.sla_compliance_rate >= 95 ? 'text-success' : 'text-danger'}">${data.summary.sla_compliance_rate}%</div>
                        <div class="metric-label">SLA Compliance</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-info">${data.summary.avg_response_time_hours}h</div>
                        <div class="metric-label">Avg Response Time</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-warning">${data.summary.sla_breaches}</div>
                        <div class="metric-label">SLA Breaches</div>
                    </div>
                </div>
            </div>

            <!-- Priority and Status Breakdown -->
            <div class="row">
                <div class="col-md-6">
                    <div class="chart-container">
                        <h5>Priority Distribution</h5>
                        <canvas id="segmentPriorityChart"></canvas>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="chart-container">
                        <h5>Status Distribution</h5>
                        <canvas id="segmentStatusChart"></canvas>
                    </div>
                </div>
            </div>
        `;

        // Render charts
        this.renderPriorityChart(data.breakdowns.priority, 'segmentPriorityChart');
        this.renderStatusChart(data.breakdowns.status, 'segmentStatusChart');
    }

    async loadOutages() {
        this.showLoading();
        
        try {
            const response = await fetch(this.buildApiUrl('/api/dashboard/outages'));
            const data = await response.json();
            
            this.renderOutages(data);
        } catch (error) {
            this.showError('Failed to load outages data');
        }
    }

    renderOutages(data) {
        const contentArea = document.getElementById('content-area');
        
        contentArea.innerHTML = `
            <div class="row mb-4">
                <div class="col-12">
                    <h3>Service Outages Analysis</h3>
                </div>
            </div>

            <!-- Outage Metrics -->
            <div class="row mb-4">
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-danger">${data.summary.total_outages}</div>
                        <div class="metric-label">Total Outages</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-warning">${data.summary.ongoing_outages}</div>
                        <div class="metric-label">Ongoing Outages</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-info">${Math.round(data.summary.total_downtime_minutes)}m</div>
                        <div class="metric-label">Total Downtime</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-success">${Math.round(data.summary.mttr_minutes)}m</div>
                        <div class="metric-label">MTTR</div>
                    </div>
                </div>
            </div>

            <!-- Outage Charts -->
            <div class="row mb-4">
                <div class="col-md-6">
                    <div class="chart-container">
                        <h5>Outages by Severity</h5>
                        <canvas id="severityChart"></canvas>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="chart-container">
                        <h5>Outages by Product Line</h5>
                        <canvas id="productLineChart"></canvas>
                    </div>
                </div>
            </div>

            <!-- Outage Timeline -->
            <div class="row">
                <div class="col-12">
                    <div class="chart-container">
                        <h5>Recent Outages</h5>
                        <div class="table-responsive">
                            <table class="table table-striped">
                                <thead>
                                    <tr>
                                        <th>Product Line</th>
                                        <th>Start Time</th>
                                        <th>Duration</th>
                                        <th>Severity</th>
                                        <th>Status</th>
                                        <th>Root Cause</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${data.outages.slice(0, 10).map(outage => `
                                        <tr>
                                            <td><span class="badge bg-secondary">${outage.product_line}</span></td>
                                            <td>${new Date(outage.start_time).toLocaleString()}</td>
                                            <td>${Math.round(outage.duration_minutes)}m</td>
                                            <td>
                                                <span class="badge ${this.getSeverityBadgeClass(outage.severity)}">
                                                    ${outage.severity}
                                                </span>
                                            </td>
                                            <td>
                                                <span class="status-badge ${outage.is_ongoing ? 'status-breach' : 'status-compliant'}">
                                                    ${outage.is_ongoing ? 'Ongoing' : 'Resolved'}
                                                </span>
                                            </td>
                                            <td>${outage.root_cause ? outage.root_cause.substring(0, 50) + '...' : 'N/A'}</td>
                                        </tr>
                                    `).join('')}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Render charts
        this.renderSeverityChart(data.breakdowns.severity);
        this.renderProductLineChart(data.breakdowns.product_line);
    }

    async loadExecutiveSummary() {
        this.showLoading();
        
        try {
            const response = await fetch(this.buildApiUrl('/api/dashboard/executive-summary'));
            const data = await response.json();
            
            this.renderExecutiveSummary(data);
        } catch (error) {
            this.showError('Failed to load executive summary');
        }
    }

    renderExecutiveSummary(data) {
        const contentArea = document.getElementById('content-area');
        
        contentArea.innerHTML = `
            <div class="row mb-4">
                <div class="col-12">
                    <h3>Executive Summary</h3>
                    <p class="text-muted">Period: ${new Date(data.period.start_date).toLocaleDateString()} - ${new Date(data.period.end_date).toLocaleDateString()}</p>
                </div>
            </div>

            <!-- Key Performance Indicators -->
            <div class="row mb-4">
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-primary">${data.key_metrics.total_tickets}</div>
                        <div class="metric-label">Total Tickets</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value ${data.key_metrics.sla_compliance_rate >= 95 ? 'text-success' : 'text-danger'}">${data.key_metrics.sla_compliance_rate}%</div>
                        <div class="metric-label">SLA Compliance</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-warning">${data.key_metrics.sla_breaches}</div>
                        <div class="metric-label">SLA Breaches</div>
                    </div>
                </div>
                <div class="col-md-3">
                    <div class="metric-card">
                        <div class="metric-value text-danger">${data.key_metrics.total_outages}</div>
                        <div class="metric-label">Service Outages</div>
                    </div>
                </div>
            </div>

            <!-- Executive Summary Text -->
            <div class="row mb-4">
                <div class="col-12">
                    <div class="chart-container">
                        <h5>Executive Summary Report</h5>
                        <div class="p-3" style="background-color: #f8f9fa; border-radius: 8px;">
                            <pre style="white-space: pre-wrap; font-family: inherit;">${data.summary_text}</pre>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Top Issues -->
            <div class="row">
                <div class="col-12">
                    <div class="chart-container">
                        <h5>Top Issues</h5>
                        <div class="table-responsive">
                            <table class="table table-striped">
                                <thead>
                                    <tr>
                                        <th>Issue Type</th>
                                        <th>Count</th>
                                        <th>Percentage</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${data.top_issues.map(issue => {
                                        const percentage = ((issue.count / data.key_metrics.total_tickets) * 100).toFixed(1);
                                        return `
                                            <tr>
                                                <td>${issue.issue_type}</td>
                                                <td>${issue.count}</td>
                                                <td>
                                                    <div class="progress progress-custom">
                                                        <div class="progress-bar" style="width: ${percentage}%"></div>
                                                    </div>
                                                    ${percentage}%
                                                </td>
                                            </tr>
                                        `;
                                    }).join('')}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Export Options -->
            <div class="row">
                <div class="col-12">
                    <div class="chart-container">
                        <h5>Export Options</h5>
                        <div class="d-flex gap-2">
                            <button class="btn btn-outline-primary" onclick="dashboard.exportToPDF()">
                                <i class="fas fa-file-pdf me-2"></i>Export to PDF
                            </button>
                            <button class="btn btn-outline-success" onclick="dashboard.exportToExcel()">
                                <i class="fas fa-file-excel me-2"></i>Export to Excel
                            </button>
                            <button class="btn btn-outline-info" onclick="dashboard.exportToPowerPoint()">
                                <i class="fas fa-file-powerpoint me-2"></i>Export to PowerPoint
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    loadDataManagement() {
        const contentArea = document.getElementById('content-area');
        
        contentArea.innerHTML = `
            <div class="row mb-4">
                <div class="col-12">
                    <h3>Data Management</h3>
                </div>
            </div>

            <!-- Data Import/Export -->
            <div class="row mb-4">
                <div class="col-md-6">
                    <div class="chart-container">
                        <h5>Data Import</h5>
                        <p>Import fresh ticket data from Freshdesk</p>
                        <button class="btn btn-primary" onclick="dashboard.importFreshdeskData()">
                            <i class="fas fa-upload me-2"></i>Import Freshdesk Data
                        </button>
                    </div>
                </div>
                <div class="col-md-6">
                    <div class="chart-container">
                        <h5>Data Export</h5>
                        <p>Export current dashboard data</p>
                        <div class="d-flex gap-2">
                            <button class="btn btn-outline-primary" onclick="dashboard.exportData('json')">
                                <i class="fas fa-download me-2"></i>JSON
                            </button>
                            <button class="btn btn-outline-success" onclick="dashboard.exportData('csv')">
                                <i class="fas fa-download me-2"></i>CSV
                            </button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Data Statistics -->
            <div class="row">
                <div class="col-12">
                    <div class="chart-container">
                        <h5>Data Statistics</h5>
                        <div id="dataStats">Loading...</div>
                    </div>
                </div>
            </div>
        `;

        this.loadDataStatistics();
    }

    async loadDataStatistics() {
        try {
            const [customersResponse, slaResponse] = await Promise.all([
                fetch('/api/extraction/customers'),
                fetch('/api/extraction/sla-definitions')
            ]);

            const customers = await customersResponse.json();
            const slaDefinitions = await slaResponse.json();

            document.getElementById('dataStats').innerHTML = `
                <div class="row">
                    <div class="col-md-6">
                        <h6>Customers</h6>
                        <p>Total customers: ${customers.customers.length}</p>
                        <ul>
                            ${Object.entries(
                                customers.customers.reduce((acc, customer) => {
                                    acc[customer.customer_type] = (acc[customer.customer_type] || 0) + 1;
                                    return acc;
                                }, {})
                            ).map(([type, count]) => `<li>${type}: ${count}</li>`).join('')}
                        </ul>
                    </div>
                    <div class="col-md-6">
                        <h6>SLA Definitions</h6>
                        <p>Total SLA rules: ${slaDefinitions.sla_definitions.length}</p>
                        <div class="table-responsive">
                            <table class="table table-sm">
                                <thead>
                                    <tr>
                                        <th>Customer Type</th>
                                        <th>Priority</th>
                                        <th>Response Time</th>
                                        <th>Resolution Time</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${slaDefinitions.sla_definitions.slice(0, 5).map(sla => `
                                        <tr>
                                            <td>${sla.customer_type}</td>
                                            <td>${sla.priority}</td>
                                            <td>${sla.response_time_hours}h</td>
                                            <td>${sla.resolution_time_hours}h</td>
                                        </tr>
                                    `).join('')}
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            `;
        } catch (error) {
            document.getElementById('dataStats').innerHTML = '<p class="text-danger">Failed to load data statistics</p>';
        }
    }

    // Chart rendering methods
    renderComplianceTrendChart(trends) {
        const ctx = document.getElementById('complianceTrendChart').getContext('2d');
        
        if (this.charts.complianceTrend) {
            this.charts.complianceTrend.destroy();
        }

        this.charts.complianceTrend = new Chart(ctx, {
            type: 'line',
            data: {
                labels: trends.map(t => new Date(t.date).toLocaleDateString()),
                datasets: [{
                    label: 'SLA Compliance Rate',
                    data: trends.map(t => t.sla_compliance_rate),
                    borderColor: '#3498db',
                    backgroundColor: 'rgba(52, 152, 219, 0.1)',
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            callback: function(value) {
                                return value + '%';
                            }
                        }
                    }
                }
            }
        });
    }

    renderPriorityChart(priorityData, chartId = 'priorityChart') {
        const ctx = document.getElementById(chartId).getContext('2d');
        
        if (this.charts[chartId]) {
            this.charts[chartId].destroy();
        }

        const labels = Object.keys(priorityData);
        const data = Object.values(priorityData).map(p => p.total);
        const colors = ['#e74c3c', '#f39c12', '#3498db', '#27ae60'];

        this.charts[chartId] = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: colors.slice(0, labels.length)
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        });
    }

    renderStatusChart(statusData, chartId) {
        const ctx = document.getElementById(chartId).getContext('2d');
        
        if (this.charts[chartId]) {
            this.charts[chartId].destroy();
        }

        const labels = Object.keys(statusData);
        const data = Object.values(statusData);
        const colors = ['#27ae60', '#f39c12', '#e74c3c', '#3498db', '#9b59b6'];

        this.charts[chartId] = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Tickets',
                    data: data,
                    backgroundColor: colors.slice(0, labels.length)
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

    renderSeverityChart(severityData) {
        const ctx = document.getElementById('severityChart').getContext('2d');
        
        if (this.charts.severity) {
            this.charts.severity.destroy();
        }

        const labels = Object.keys(severityData);
        const data = Object.values(severityData);
        const colors = ['#27ae60', '#f39c12', '#e74c3c', '#8e44ad'];

        this.charts.severity = new Chart(ctx, {
            type: 'pie',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: colors.slice(0, labels.length)
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        });
    }

    renderProductLineChart(productData) {
        const ctx = document.getElementById('productLineChart').getContext('2d');
        
        if (this.charts.productLine) {
            this.charts.productLine.destroy();
        }

        const labels = Object.keys(productData);
        const data = Object.values(productData).map(p => p.count);

        this.charts.productLine = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Outages',
                    data: data,
                    backgroundColor: '#e74c3c'
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

    // Utility methods
    buildApiUrl(endpoint, params = {}) {
        const url = new URL(endpoint, window.location.origin);
        
        // Add date filters
        if (this.currentFilters.startDate) {
            url.searchParams.append('start_date', this.currentFilters.startDate + 'T00:00:00Z');
        }
        if (this.currentFilters.endDate) {
            url.searchParams.append('end_date', this.currentFilters.endDate + 'T23:59:59Z');
        }
        if (this.currentFilters.customerType !== 'all') {
            url.searchParams.append('customer_type', this.currentFilters.customerType);
        }

        // Add additional params
        Object.entries(params).forEach(([key, value]) => {
            url.searchParams.append(key, value);
        });

        return url.toString();
    }

    getSeverityBadgeClass(severity) {
        const classes = {
            'Critical': 'bg-danger',
            'High': 'bg-warning',
            'Medium': 'bg-info',
            'Low': 'bg-success'
        };
        return classes[severity] || 'bg-secondary';
    }

    showLoading(message = 'Loading...') {
        const contentArea = document.getElementById('content-area');
        contentArea.innerHTML = `
            <div class="loading-spinner">
                <div class="text-center">
                    <div class="spinner-border text-primary" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <p class="mt-2">${message}</p>
                </div>
            </div>
        `;
    }

    showError(message) {
        const contentArea = document.getElementById('content-area');
        contentArea.innerHTML = `
            <div class="alert alert-danger">
                <h4><i class="fas fa-exclamation-triangle me-2"></i>Error</h4>
                <p>${message}</p>
                <button class="btn btn-outline-danger" onclick="dashboard.loadSection(dashboard.currentSection)">
                    <i class="fas fa-redo me-2"></i>Retry
                </button>
            </div>
        `;
    }

    showSuccess(message) {
        const contentArea = document.getElementById('content-area');
        contentArea.innerHTML = `
            <div class="alert alert-success">
                <h4><i class="fas fa-check-circle me-2"></i>Success</h4>
                <p>${message}</p>
            </div>
        `;
    }

    // Export methods
    async exportData(format = 'json') {
        try {
            const response = await fetch(this.buildApiUrl('/api/dashboard/tickets', { per_page: 1000 }));
            const data = await response.json();
            
            if (format === 'json') {
                this.downloadJSON(data, 'sla-dashboard-data.json');
            } else if (format === 'csv') {
                this.downloadCSV(data.tickets, 'sla-dashboard-data.csv');
            }
        } catch (error) {
            this.showError('Failed to export data');
        }
    }

    downloadJSON(data, filename) {
        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.click();
        URL.revokeObjectURL(url);
    }

    downloadCSV(data, filename) {
        if (!data.length) return;
        
        const headers = Object.keys(data[0]);
        const csvContent = [
            headers.join(','),
            ...data.map(row => headers.map(header => {
                const value = row[header];
                return typeof value === 'string' ? `"${value.replace(/"/g, '""')}"` : value;
            }).join(','))
        ].join('\n');
        
        const blob = new Blob([csvContent], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.click();
        URL.revokeObjectURL(url);
    }

    exportToPDF() {
        window.print();
    }

    exportToExcel() {
        this.exportData('csv');
    }

    exportToPowerPoint() {
        alert('PowerPoint export feature coming soon!');
    }
}

// Global functions
function applyFilters() {
    dashboard.loadSection(dashboard.currentSection);
}

function refreshData() {
    dashboard.loadSection(dashboard.currentSection);
}

function exportData() {
    dashboard.exportData();
}

// Initialize dashboard when page loads
let dashboard;
document.addEventListener('DOMContentLoaded', () => {
    dashboard = new SLADashboard();
});

