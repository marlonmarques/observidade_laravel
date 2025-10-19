#!/bin/bash
# start-monitoring.sh
docker-compose down -v

echo "Creating necessary directories..."
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/dashboards

# Executar script de criação do dashboard
chmod +x create-laravel-dashboard.sh
./create-laravel-dashboard.sh

# Configurar data source
cat > grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://172.21.0.3:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: 5s
      queryTimeout: 60s
      httpMethod: POST
EOF

# Dashboards provisioning
cat > grafana/provisioning/dashboards/dashboards.yml << EOF
apiVersion: 1

providers:
  - name: 'laravel-dashboards'
    orgId: 1
    folder: 'Laravel'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

echo "📦 Starting Docker containers..."
docker-compose -f docker-compose.monitoring.yml down
docker-compose -f docker-compose.monitoring.yml up -d

echo "⏳ Waiting for services to be ready..."
sleep 30

# Verificar se os serviços estão rodando
echo "🔍 Checking services status..."
docker-compose -f docker-compose.monitoring.yml ps

# Testar se o dashboard foi carregado
echo "🧪 Testing dashboard import..."
curl -s "http://localhost:4000/api/search?query=laravel" | jq . || echo "Grafana not ready yet, waiting..."

echo "🎉 Deployment completed!"
echo ""
echo "📊 Access URLs:"
echo "   Grafana:      http://localhost:4000 (admin/admin)"
echo "   Prometheus:   http://localhost:9090"
echo "   Laravel App:  http://localhost:8000"
echo ""
echo "🔧 Next steps:"
echo "   1. Generate some traffic to see metrics:"
echo "      curl http://localhost:8000/test"
echo "      curl http://localhost:8000/health"
echo "   2. Check metrics endpoint:"
echo "      curl -u monitor:your-secret-password http://localhost:8000/metrics"
echo "   3. View dashboard in Grafana"
