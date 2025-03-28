#!/bin/bash

# Скрипт для экспорта данных о старых запусках из контейнера Airflow в /home/mgpu/airflow_export

# Параметры
CONTAINER_NAME="business_case_rocket_25-scheduler-1"
AIRFLOW_DATA_DIR="/opt/airflow/data"
HOST_EXPORT_DIR="/home/mgpu/airflow_export"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXPORT_PATH="$HOST_EXPORT_DIR/past_launches_$TIMESTAMP" # Добавляем префикс для старых запусков

# Проверяем существование директории /home/mgpu
if [ ! -d "/home/mgpu" ]; then
    echo "Ошибка: Директория /home/mgpu не существует!"
    exit 1
fi

# Создаем директорию для экспорта
mkdir -p "$EXPORT_PATH/images"

# Устанавливаем правильные права
chown -R mgpu:mgpu "$HOST_EXPORT_DIR"
chmod -R 755 "$HOST_EXPORT_DIR"

# 1. Копируем файл past_launches.json (или launches.json, если у вас старые данные там)
echo "Копируем past_launches.json..."
if docker exec "$CONTAINER_NAME" test -f "$AIRFLOW_DATA_DIR/past_launches.json"; then
    docker cp "$CONTAINER_NAME:$AIRFLOW_DATA_DIR/past_launches.json" "$EXPORT_PATH/" && \
        chown mgpu:mgpu "$EXPORT_PATH/past_launches.json" || \
        echo "Не удалось скопировать past_launches.json"
elif docker exec "$CONTAINER_NAME" test -f "$AIRFLOW_DATA_DIR/launches.json"; then
    echo "Файл past_launches.json не найден, копируем launches.json..."
    docker cp "$CONTAINER_NAME:$AIRFLOW_DATA_DIR/launches.json" "$EXPORT_PATH/" && \
        chown mgpu:mgpu "$EXPORT_PATH/launches.json" || \
        echo "Не удалось скопировать launches.json"
else
    echo "Файлы past_launches.json и launches.json не найдены"
fi

# 2. Копируем изображения (из past_images или images)
echo "Копируем изображения..."
PAST_IMAGES_DIR="$AIRFLOW_DATA_DIR/past_images"
IMAGES_DIR="$AIRFLOW_DATA_DIR/images"

if docker exec "$CONTAINER_NAME" test -d "$PAST_IMAGES_DIR"; then
    echo "Копируем изображения из $PAST_IMAGES_DIR..."
    docker cp "$CONTAINER_NAME:$PAST_IMAGES_DIR/" "$EXPORT_PATH/images/" && \
        chown -R mgpu:mgpu "$EXPORT_PATH/images" || \
        echo "Не удалось скопировать изображения из $PAST_IMAGES_DIR"
elif docker exec "$CONTAINER_NAME" test -d "$IMAGES_DIR"; then
    echo "Директория $PAST_IMAGES_DIR не найдена, копируем из $IMAGES_DIR..."
    docker cp "$CONTAINER_NAME:$IMAGES_DIR/" "$EXPORT_PATH/images/" && \
        chown -R mgpu:mgpu "$EXPORT_PATH/images" || \
        echo "Не удалось скопировать изображения из $IMAGES_DIR"
else
    echo "Директории с изображениями не найдены в контейнере"
fi

# 3. Создаем файл с информацией
echo "Создаем README..."
echo "Данные о старых запусках экспортированы из контейнера $CONTAINER_NAME" > "$EXPORT_PATH/README.txt"
echo "Дата экспорта: $(date)" >> "$EXPORT_PATH/README.txt"
echo "Количество изображений: $(ls -1 "$EXPORT_PATH/images/" 2>/dev/null | wc -l)" >> "$EXPORT_PATH/README.txt"
chown mgpu:mgpu "$EXPORT_PATH/README.txt"

echo "Данные успешно экспортированы в $EXPORT_PATH"
echo "Владелец файлов: $(stat -c '%U:%G' "$EXPORT_PATH")"
