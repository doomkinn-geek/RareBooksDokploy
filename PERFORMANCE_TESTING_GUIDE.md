# May Messenger - Performance Testing Guide

## Цель
Нагрузочное тестирование с 100+ параллельными клиентами для проверки:
- Стабильности backend под нагрузкой
- Масштабируемости SignalR соединений
- Производительности базы данных
- Отсутствия memory leaks

## Инструменты

### 1. Backend Load Testing
- **k6** (рекомендуется) - https://k6.io/
- **Artillery** - https://artillery.io/
- **JMeter** - для более сложных сценариев

### 2. SignalR Load Testing
- **Crank** - Microsoft's SignalR benchmarking tool
- **Custom script** - на Python с signalrcore

### 3. Мониторинг
- **Grafana + Prometheus** - для метрик
- **Docker stats** - для контейнеров
- **PostgreSQL pg_stat_statements** - для БД запросов

## Предварительные требования

### Backend Setup
```bash
# Убедиться, что все сервисы запущены
docker-compose ps

# Проверить логи
docker logs -f maymessenger_backend

# Проверить метрики
curl https://messenger.rare-books.ru/api/diagnostics/metrics
```

### Тестовые пользователи
Создать 100+ тестовых пользователей:
```sql
-- Скрипт для создания тестовых пользователей
DO $$
DECLARE
    i INTEGER;
BEGIN
    FOR i IN 1..150 LOOP
        INSERT INTO "Users" ("Id", "PhoneNumber", "DisplayName", "PasswordHash", "CreatedAt")
        VALUES (
            gen_random_uuid(),
            '+7900' || LPAD(i::text, 7, '0'),
            'TestUser' || i,
            'hash_placeholder', -- Реальный хеш пароля
            NOW()
        )
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$;
```

## Сценарии тестирования

### Scenario 1: REST API Load Test

**Цель**: Проверить производительность REST API

**Инструмент**: k6

**Скрипт** (`load_test_rest.js`):
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 150 },  // Ramp up to 150 users
    { duration: '3m', target: 150 },  // Stay at 150 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete within 500ms
    http_req_failed: ['rate<0.01'],   // Error rate must be < 1%
  },
};

const BASE_URL = 'https://messenger.rare-books.ru';
const TOKEN = __ENV.AUTH_TOKEN; // Pass via -e AUTH_TOKEN=...

export default function () {
  // Test 1: Send Message
  const sendPayload = JSON.stringify({
    type: 0, // Text
    content: `Load test message ${Date.now()}`,
    clientMessageId: `test-${__VU}-${Date.now()}`,
  });

  const sendRes = http.post(
    `${BASE_URL}/api/messages/${__ENV.CHAT_ID}`,
    sendPayload,
    {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${TOKEN}`,
      },
    }
  );

  check(sendRes, {
    'send message status 200': (r) => r.status === 200,
    'send message < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);

  // Test 2: Get Messages
  const getRes = http.get(
    `${BASE_URL}/api/messages/${__ENV.CHAT_ID}?take=50`,
    {
      headers: {
        'Authorization': `Bearer ${TOKEN}`,
      },
    }
  );

  check(getRes, {
    'get messages status 200': (r) => r.status === 200,
    'get messages < 300ms': (r) => r.timings.duration < 300,
  });

  sleep(2);

  // Test 3: Search Messages
  const searchRes = http.get(
    `${BASE_URL}/api/messages/search?query=test`,
    {
      headers: {
        'Authorization': `Bearer ${TOKEN}`,
      },
    }
  );

  check(searchRes, {
    'search messages status 200': (r) => r.status === 200,
    'search messages < 1s': (r) => r.timings.duration < 1000,
  });

  sleep(3);
}
```

**Запуск**:
```bash
k6 run --vus 100 --duration 10m load_test_rest.js
```

**Метрики для проверки**:
- `http_req_duration` (p95) < 500ms
- `http_req_failed` < 1%
- `http_reqs` (throughput) > 100 req/s

### Scenario 2: SignalR Connection Load Test

**Цель**: Проверить масштабируемость SignalR соединений

**Инструмент**: Python script

**Скрипт** (`load_test_signalr.py`):
```python
import asyncio
import aiohttp
from signalrcore.hub_connection_builder import HubConnectionBuilder
import time
import random
from concurrent.futures import ThreadPoolExecutor

BASE_URL = "https://messenger.rare-books.ru"
CHAT_ID = "your-chat-id"
NUM_CLIENTS = 100
DURATION_MINUTES = 10

class SignalRClient:
    def __init__(self, user_id, token):
        self.user_id = user_id
        self.token = token
        self.messages_received = 0
        self.connection = None
        
    async def connect(self):
        self.connection = HubConnectionBuilder()\
            .with_url(f"{BASE_URL}/hubs/chat", options={
                "access_token_factory": lambda: self.token,
            })\
            .with_automatic_reconnect({
                "type": "interval",
                "intervals": [0, 2, 5, 10, 30],
            })\
            .build()
        
        self.connection.on("ReceiveMessage", self.on_message_received)
        self.connection.on("MessageStatusUpdated", self.on_status_updated)
        
        await self.connection.start()
        print(f"[Client {self.user_id}] Connected")
        
    def on_message_received(self, message):
        self.messages_received += 1
        
    def on_status_updated(self, message_id, status):
        pass
        
    async def send_message(self, content):
        # Send via REST API (SignalR SendMessage is deprecated)
        async with aiohttp.ClientSession() as session:
            payload = {
                "type": 0,
                "content": content,
                "clientMessageId": f"load-{self.user_id}-{time.time()}",
            }
            headers = {
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            }
            async with session.post(
                f"{BASE_URL}/api/messages/{CHAT_ID}",
                json=payload,
                headers=headers,
            ) as resp:
                return resp.status == 200
                
    async def run_scenario(self, duration_seconds):
        start_time = time.time()
        while time.time() - start_time < duration_seconds:
            # Random sleep 5-15 seconds
            await asyncio.sleep(random.uniform(5, 15))
            
            # Send a message
            content = f"Load test from user {self.user_id} at {time.time()}"
            await self.send_message(content)
            
        print(f"[Client {self.user_id}] Finished. Received {self.messages_received} messages")

async def main():
    # Create clients
    tokens = get_user_tokens(NUM_CLIENTS)  # Implement this
    clients = [SignalRClient(i, tokens[i]) for i in range(NUM_CLIENTS)]
    
    # Connect all clients
    print(f"Connecting {NUM_CLIENTS} clients...")
    await asyncio.gather(*[client.connect() for client in clients])
    print("All clients connected!")
    
    # Run load test
    duration = DURATION_MINUTES * 60
    print(f"Running load test for {DURATION_MINUTES} minutes...")
    await asyncio.gather(*[client.run_scenario(duration) for client in clients])
    
    # Disconnect
    print("Disconnecting clients...")
    # Implementation here
    
    # Print stats
    total_received = sum(client.messages_received for client in clients)
    print(f"\n=== RESULTS ===")
    print(f"Total clients: {NUM_CLIENTS}")
    print(f"Total messages received: {total_received}")
    print(f"Average per client: {total_received / NUM_CLIENTS:.2f}")

if __name__ == "__main__":
    asyncio.run(main())
```

**Запуск**:
```bash
python load_test_signalr.py
```

**Метрики для проверки**:
- Все 100 клиентов успешно подключены
- Reconnection работает (если есть разрывы)
- Heartbeat работает для всех клиентов
- Нет потерянных сообщений

### Scenario 3: Database Performance Test

**Цель**: Проверить производительность PostgreSQL под нагрузкой

**Подготовка**:
```sql
-- Включить pg_stat_statements для мониторинга
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Сбросить статистику
SELECT pg_stat_statements_reset();
```

**Во время теста**:
```sql
-- Top 10 самых медленных запросов
SELECT 
    substring(query, 1, 100) as short_query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Проверить использование индексов
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- Проверить блокировки
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    backend_start,
    query_start,
    state,
    wait_event_type,
    wait_event,
    query
FROM pg_stat_activity
WHERE state != 'idle';
```

**Метрики для проверки**:
- Нет долгих блокировок (> 1 секунда)
- Все индексы используются эффективно
- Mean query execution time < 50ms
- No table scans на больших таблицах

### Scenario 4: Memory Leak Test

**Цель**: Проверить отсутствие memory leaks

**Инструмент**: Docker monitoring + dotnet-counters

**Мониторинг**:
```bash
# Мониторинг контейнера
watch -n 5 'docker stats maymessenger_backend --no-stream'

# Или подробные метрики .NET
docker exec maymessenger_backend dotnet-counters monitor --process-id 1
```

**Проверка**:
- [ ] Memory usage стабилизируется после warm-up (первые 10 минут)
- [ ] Нет непрерывного роста memory
- [ ] GC работает эффективно (Gen 2 collections < 5 в минуту)
- [ ] Heap size не превышает 2GB

## Мониторинг во время тестов

### Backend Metrics

**DiagnosticsController**:
```bash
# Метрики в начале теста
curl -H "Authorization: Bearer TOKEN" \
  https://messenger.rare-books.ru/api/diagnostics/metrics > start_metrics.json

# Метрики в конце теста
curl -H "Authorization: Bearer TOKEN" \
  https://messenger.rare-books.ru/api/diagnostics/metrics > end_metrics.json

# Сравнить
diff start_metrics.json end_metrics.json
```

### Docker Stats

```bash
# Continuous monitoring
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
  maymessenger_backend db_maymessenger nginx_container
```

### Nginx Logs

```bash
# Access log analysis
docker exec nginx_container tail -f /var/log/nginx/signalr_access.log

# Error log
docker exec nginx_container tail -f /var/log/nginx/signalr_error.log
```

## Критерии успеха

### Обязательные

- ✅ **100+ concurrent connections**: Все клиенты подключены стабильно
- ✅ **< 1% error rate**: Менее 1% ошибок при всех запросах
- ✅ **p95 latency < 500ms**: 95% запросов выполняются < 500ms
- ✅ **No memory leaks**: Memory usage стабилизируется
- ✅ **No crashes**: Backend не крашится под нагрузкой

### Желательные

- ⭐ **200+ concurrent connections**: Масштабируемость до 200 клиентов
- ⭐ **p95 latency < 300ms**: Еще более быстрые ответы
- ⭐ **< 0.1% error rate**: Практически нет ошибок
- ⭐ **CPU usage < 70%**: Эффективное использование ресурсов
- ⭐ **DB response time < 50ms**: Быстрая база данных

## Результаты и отчетность

### Формат отчета

```markdown
# Performance Test Results - May Messenger

## Test Configuration
- Date: YYYY-MM-DD
- Duration: X minutes
- Concurrent Users: 100
- Total Requests: XXXXX
- Backend Version: 2.0.0

## Results Summary

### REST API
- Total Requests: XXXXX
- Success Rate: XX.X%
- Error Rate: X.XX%
- p50 Latency: XXXms
- p95 Latency: XXXms
- p99 Latency: XXXms
- Throughput: XXX req/s

### SignalR
- Concurrent Connections: XXX
- Connection Success Rate: XX.X%
- Messages Sent: XXXXX
- Messages Received: XXXXX
- Message Loss Rate: X.XX%
- Reconnections: XXX

### Database
- Total Queries: XXXXX
- Mean Query Time: XXms
- Max Query Time: XXXms
- Cache Hit Rate: XX.X%
- Connections Used: XXX

### System Resources
- Peak CPU Usage: XX%
- Peak Memory Usage: XXXMB
- Network I/O: XX MB/s
- Disk I/O: XX MB/s

## Issues Found
1. [Description]
2. [Description]

## Recommendations
1. [Recommendation]
2. [Recommendation]

## Conclusion
PASS / FAIL

**Tested by**: ________________
**Approved by**: ________________
```

## Troubleshooting

### Проблема: High error rate

**Симптомы**: Error rate > 5%

**Решения**:
1. Проверить логи backend: `docker logs maymessenger_backend`
2. Проверить подключения к БД: `SELECT count(*) FROM pg_stat_activity`
3. Увеличить connection pool size в appsettings.json
4. Проверить rate limiting в nginx

### Проблема: High latency

**Симптомы**: p95 > 1 секунда

**Решения**:
1. Проверить медленные запросы в БД
2. Добавить недостающие индексы
3. Проверить N+1 query problems
4. Включить response caching для GET запросов

### Проблема: Memory leak

**Симптомы**: Memory непрерывно растет

**Решения**:
1. Проверить dotnet-counters для GC metrics
2. Использовать dotnet-dump для анализа heap
3. Проверить закрытие SignalR connections
4. Проверить disposal of DbContext

### Проблема: SignalR disconnections

**Симптомы**: Частые reconnects

**Решения**:
1. Проверить nginx timeouts (должны быть 7d для WebSocket)
2. Проверить heartbeat работает корректно
3. Увеличить MaximumReceiveMessageSize в SignalR
4. Проверить firewall/load balancer settings

## Автоматизация

### CI/CD Integration

```yaml
# .github/workflows/performance-test.yml
name: Performance Test

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday 2 AM
  workflow_dispatch:

jobs:
  performance-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup k6
        run: |
          sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
          echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
          sudo apt-get update
          sudo apt-get install k6
          
      - name: Run k6 test
        run: k6 run --out json=results.json load_test_rest.js
        
      - name: Upload results
        uses: actions/upload-artifact@v2
        with:
          name: performance-results
          path: results.json
```

## Заключение

Performance testing критически важен для гарантии качества после рефакторинга. Все метрики должны соответствовать критериям успеха перед деплоем на production.

**Минимальные требования**: Пройти Scenario 1 и Scenario 2 с обязательными критериями.

**Рекомендуется**: Пройти все 4 сценария с желательными критериями.

