#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/исходные данные"

echo "=== Загрузка данных в PostgreSQL (файлы 1-5) ==="

PG_FILES=("MOCK_DATA.csv" "MOCK_DATA (1).csv" "MOCK_DATA (2).csv" "MOCK_DATA (3).csv" "MOCK_DATA (4).csv")

for file in "${PG_FILES[@]}"; do
    echo "  Загружаю: $file"
    docker cp "$DATA_DIR/$file" postgres:/tmp/data.csv
    docker exec postgres psql -U postgres -d source_db \
        -c "COPY mock_data FROM '/tmp/data.csv' WITH (FORMAT csv, HEADER true)"
    docker exec postgres rm /tmp/data.csv
done

echo "  Проверка: $(docker exec postgres psql -U postgres -d source_db -t -c "SELECT count(*) FROM mock_data") строк в PostgreSQL"

echo ""
echo "=== Загрузка данных в ClickHouse (файлы 6-10) ==="

CH_FILES=("MOCK_DATA (5).csv" "MOCK_DATA (6).csv" "MOCK_DATA (7).csv" "MOCK_DATA (8).csv" "MOCK_DATA (9).csv")

for file in "${CH_FILES[@]}"; do
    echo "  Загружаю: $file"
    docker exec -i clickhouse clickhouse-client \
        --query="INSERT INTO default.mock_data FORMAT CSVWithNames" < "$DATA_DIR/$file"
done

echo "  Проверка: $(docker exec clickhouse clickhouse-client --query="SELECT count(*) FROM default.mock_data") строк в ClickHouse"

echo ""
echo "=== Загрузка данных завершена ==="
