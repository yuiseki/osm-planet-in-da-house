# osm-planet-in-da-house

This document outlines the procedure for running the entire OpenStreetMap planet dataset in a local environment.

## Recommended Machine Specifications

- **Memory:** 96GB or more
- **Storage:** At least 500GB of free space on a high-speed SSD (NVMe recommended)
- **CPU:** Multi-core CPU

## Required Packages

- `docker`
- `docker-compose`
- `make`
- `aria2c`

## Execution Steps

1.  **Pull Docker Images**

    Execute the following command to download the necessary Docker images in advance.

    ```bash
    make docker-pull
    ```

2.  **Download OpenStreetMap Planet Data**

    Use `aria2c` to download the latest planet data. This may take several hours.

    ```bash
    ./00_download_planet.sh
    ```

3.  **Process Data**

    Process the downloaded data with Planetiler to generate map tiles and other assets. This process is very time-consuming.

    ```bash
    ./01_runworld.sh
    ```
    *Note: This script consumes a large amount of memory (90GB).*

4.  **Start Services**

    Once all data processing is complete, start the services, including the tile server and search engines, with the following command.

    ```bash
    docker compose up
    ```

    After startup, you can access the following endpoints:
    - TileServer: `http://localhost:8000` - Vector tile distribution
    - Nominatim: `http://localhost:8001` - Geocoding and reverse geocoding
    - Valhalla: `http://localhost:8002` - Route searching
    - Overpass: `http://localhost:8003` - Advanced spatial queries

    **Note:** By default, Nominatim is configured for `admin` boundaries only, and the Overpass API is set up for Monaco. You can change these settings in the `docker-compose.yml` file.
