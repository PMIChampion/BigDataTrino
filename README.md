# Лабораторная работа №4 — ETL с помощью Trino

## Описание

ETL-пайплайн на базе Trino, который трансформирует данные из **PostgreSQL** и **ClickHouse** в модель данных «снежинка» в ClickHouse, а затем создаёт 6 аналитических витрин-отчётов.

## Архитектура

```
┌──────────────┐     ┌──────────────┐
│  PostgreSQL  │     │  ClickHouse  │
│  (5000 строк)│     │  (5000 строк)│
│  файлы 1–5   │     │  файлы 6–10  │
└──────┬───────┘     └──────┬───────┘
       │                    │
       └────────┬───────────┘
                │
         ┌──────▼──────┐
         │    Trino     │
         │  (ETL SQL)   │
         └──────┬───────┘
                │
    ┌───────────▼───────────┐
    │  ClickHouse (dwh)     │
    │  ┌─────────────────┐  │
    │  │ Модель снежинка  │  │
    │  │ dim_* + fact_*   │  │
    │  └────────┬────────┘  │
    │  ┌────────▼────────┐  │
    │  │  6 отчётов       │  │
    │  │  report_*        │  │
    │  └─────────────────┘  │
    └───────────────────────┘
```

## Модель данных (снежинка)

Структура снежинки реализована через нормализацию измерений 2-го уровня:

```
fact_sales
  ├── dim_customer  ──── dim_pet        (2-й уровень: тип/порода питомца)
  ├── dim_product   ──── dim_category   (2-й уровень: категория + вид животного)
  ├── dim_seller
  ├── dim_store
  ├── dim_supplier
  └── dim_date
```

### Измерения 1-го уровня (FK из fact_sales)
| Таблица | Описание | Ключ | FK 2-го уровня |
|---------|----------|------|----------------|
| `dim_date` | Календарь | `date_key` | — |
| `dim_customer` | Клиенты | `customer_key` | `pet_key → dim_pet` |
| `dim_seller` | Продавцы | `seller_key` | — |
| `dim_product` | Продукты | `product_key` | `category_key → dim_category` |
| `dim_store` | Магазины | `store_key` | — |
| `dim_supplier` | Поставщики | `supplier_key` | — |

### Измерения 2-го уровня (снежинка)
| Таблица | Описание | Ключ |
|---------|----------|------|
| `dim_pet` | Тип/имя/порода питомца | `pet_key` |
| `dim_category` | Категория продукта + вид животного | `category_key` |

### Факты
| Таблица | Описание |
|---------|----------|
| `fact_sales` | Продажи (quantity, total_price) |

### Отчёты (report)
1. `report_sales_by_product` — выручка, количество, рейтинг по продуктам
2. `report_sales_by_customer` — покупки, средний чек по клиентам
3. `report_sales_by_time` — месячные/годовые тренды
4. `report_sales_by_store` — выручка по магазинам
5. `report_sales_by_supplier` — выручка по поставщикам
6. `report_product_quality` — рейтинги и корреляция с продажами

## Требования

- Docker и Docker Compose
- ~2 ГБ свободного места

## Быстрый запуск

```bash
# Клонировать репозиторий
git clone https://github.com/PMIChampion/BigDataTrino.git
cd BigDataTrino

# Сделать скрипты исполняемыми
chmod +x scripts/*.sh

# Запустить всё одной командой
bash scripts/run.sh
```

Скрипт `run.sh` автоматически:
1. Поднимает контейнеры (PostgreSQL, ClickHouse, Trino)
2. Ожидает готовности всех сервисов
3. Загружает CSV-данные (5 файлов → PG, 5 файлов → CH)
4. Выполняет Trino ETL (создание модели снежинка)
5. Создаёт 6 витрин-отчётов через Trino
6. Выводит статистику по таблицам

## Пошаговый запуск (вручную)

### 1. Запуск контейнеров

```bash
docker-compose up -d
```

### 2. Загрузка данных

```bash
bash scripts/01_load_data.sh
```

### 3. Trino ETL — модель снежинка

Выполнить SQL-скрипт через Trino CLI:

```bash
# Вариант A: через stdin
docker exec -i trino trino < scripts/02_trino_etl.sql

# Вариант B: по одному оператору через --execute
docker exec trino trino --execute "DROP TABLE IF EXISTS clickhouse.dwh.dim_date"
docker exec trino trino --execute "CREATE TABLE clickhouse.dwh.dim_date AS SELECT ..."
```

### 4. Trino — создание отчётов

```bash
docker exec -i trino trino < scripts/03_trino_reports.sql
```

### 5. Проверка результатов

Через DBeaver или clickhouse-client:

```bash
docker exec clickhouse clickhouse-client --query="SELECT name, total_rows FROM system.tables WHERE database = 'dwh'"
```

Проверочные запросы — файл `scripts/04_validation_queries.sql`.

## Структура репозитория

```
BigDataTrino/
├── docker-compose.yml              # Docker: PG + CH + Trino
├── README.md
├── trino/
│   └── catalog/
│       ├── postgresql.properties   # Trino → PostgreSQL
│       └── clickhouse.properties   # Trino → ClickHouse
├── postgres/
│   └── init/
│       └── 01_create_table.sql     # DDL таблицы mock_data в PG
├── clickhouse/
│   └── init/
│       └── 01_init.sql             # DDL mock_data + база dwh в CH
├── scripts/
│   ├── run.sh                      # Мастер-скрипт (всё в одном)
│   ├── 01_load_data.sh             # Загрузка CSV в PG и CH
│   ├── 02_trino_etl.sql            # Trino: исходные → снежинка (dim_pet, dim_category + FK)
│   ├── 03_trino_reports.sql        # Trino: снежинка → 6 отчётов
│   └── 04_validation_queries.sql   # SQL-запросы для проверки
└── исходные данные/
    ├── MOCK_DATA.csv
    ├── MOCK_DATA (1).csv
    ├── ...
    └── MOCK_DATA (9).csv
```

## Подключение через DBeaver

| Параметр | PostgreSQL | ClickHouse | Trino |
|----------|-----------|------------|-------|
| Host | localhost | localhost | localhost |
| Port | 5432 | 8123 | 8080 |
| Database | source_db | default / dwh | — |
| User | postgres | default | — |
| Password | postgres | (пусто) | (пусто) |

## Остановка

```bash
docker-compose down

# С удалением данных:
docker-compose down -v
```
