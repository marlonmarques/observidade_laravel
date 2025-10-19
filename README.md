
**Observabilidade em Laravel com Prometheus e Grafana**

Este projeto demonstra a integração de métricas customizadas em uma aplicação Laravel (com suporte a multi-tenant e Octane) usando Prometheus como backend de coleta e Grafana para visualização. 

**A solução permite monitorar:**

```python
Volume de requisições HTTP
Tempo de resposta por rota e tenant
Uso de memória em tempo real
```
     

**Tudo com baixo overhead, alta confiabilidade e fácil expansão.** 
 
🛠️ Requisitos 

```python
PHP 8.2+
Laravel 11
Redis (para armazenamento das métricas)
Docker e Docker Compose
Composer
```
     

📦 Instalação 
1. Instale a biblioteca do Prometheus

```bash
composer require promphp/prometheus_client_php
```
 
2. Adicione o Service Provider 

Em config/app.php, adicione: 
php
 

```python
App\Providers\MetricsServiceProvider::class,
```
 
 
3. Crie os arquivos principais 
app/Providers/MetricsServiceProvider.php 
   
```php
<?php

namespace App\Providers;

use Illuminate\Support\Facades\Arr;
use Illuminate\Support\ServiceProvider;
use Prometheus\CollectorRegistry;
use Prometheus\Storage\Redis;

class MetricsServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(CollectorRegistry::class, function () {
            Redis::setDefaultOptions(
                Arr::only(config('database.redis.default'), ['host', 'password', 'username'])
            );
            return CollectorRegistry::getDefault();
        });
    }
}
```
 
 
4. app/Http/Middleware/PrometheusMetrics.php 

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Prometheus\CollectorRegistry;
use Prometheus\Counter;
use Prometheus\Exception\MetricsRegistrationException;
use Prometheus\Histogram;
use Prometheus\Gauge;
use Symfony\Component\HttpFoundation\Response;

class PrometheusMetrics
{
    private Counter $httpRequestsCounter;
    private Histogram $responseTimeHistogram;
    private Gauge $memoryUsageGauge;

    public function __construct(CollectorRegistry $registry)
    {
        try {
            $this->httpRequestsCounter = $registry->getOrRegisterCounter(
                'http',
                'requests_total',
                'Total HTTP requests',
                ['method', 'path', 'status_code']
            );
        } catch (MetricsRegistrationException $e) {
            \Log::warning('Prometheus metric error: ' . $e->getMessage());
        }

        try {
            $this->responseTimeHistogram = $registry->getOrRegisterHistogram(
                'http',
                'response_time_seconds',
                'HTTP response time in seconds',
                ['method', 'route', 'tenant_id'],
                [0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0]
            );
        } catch (MetricsRegistrationException $e) {
            \Log::warning('Prometheus metric error: ' . $e->getMessage());
        }

        try {
            $this->memoryUsageGauge = $registry->getOrRegisterGauge(
                'system',
                'memory_usage_bytes',
                'Current memory usage in bytes'
            );
        } catch (MetricsRegistrationException $e) {
            \Log::warning('Prometheus metric error: ' . $e->getMessage());
        }
    }

    public function handle(Request $request, Closure $next): Response
    {
        if ($request->is('metrics')) {
            return $next($request);
        }

        $start = microtime(true);
        $response = $next($request);
        $duration = microtime(true) - $start;

        try {
            $method = $request->method();
            $path = $request->path();
            $statusCode = (string) $response->getStatusCode();
            $routeName = $request->route()?->getName() ?? 'unknown';
            $tenantId = tenant()?->id ?? 'global';

            $this->httpRequestsCounter->inc([$method, $path, $statusCode]);
            $this->responseTimeHistogram->observe($duration, [$method, $routeName, (string) $tenantId]);
            $this->memoryUsageGauge->set(memory_get_usage(true));

        } catch (\Throwable $e) {
            \Log::warning('Prometheus metric error: ' . $e->getMessage());
        }

        return $response;
    }
}
```

(Veja código completo no relatório técnico ou no diretório /docs)

5. Adicione a rota de métricas 

Em routes/web.php: 
```php

use Prometheus\CollectorRegistry;
use Prometheus\RenderTextFormat;

Route::get('/metrics', function (CollectorRegistry $registry) {
    $renderer = new RenderTextFormat();
    $metrics = $registry->getMetricFamilySamples();
    return response($renderer->render($metrics))
        ->header('Content-Type', RenderTextFormat::MIME_TYPE);
});
```
 
 

⚠️ Importante: Registre o middleware globalmente em app/Http/Kernel.php para que todas as requisições sejam instrumentadas. 
     

5. Inicie o ambiente de monitoramento 

```bash
bash
 
docker-compose up -d
```
 
 

Isso sobe: 

```htm
    Prometheus em http://localhost:9090
    Grafana em http://localhost:4000 (usuário: admin, senha: admin)
    Redis em localhost:6389
     

Configure o Prometheus para coletar de http://localhost:9090/metrics via prometheus.yml. 
```
 
📊 Visualização 

Acesse o Grafana e importe dashboards personalizados ou crie painéis usando as métricas: 

    http_requests_total
    http_response_time_seconds
    system_memory_usage_bytes
     

Labels como tenant_id, route e status_code permitem análises granulares. 

Link de do projeto:
https://facilfinance.com.br

