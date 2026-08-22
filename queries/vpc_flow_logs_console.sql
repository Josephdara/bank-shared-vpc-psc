-- VPC Flow Logs — BigQuery console queries (GoogleSQL)
--
-- Paste ONE query at a time into the BigQuery query editor and Run.
-- Table (host project, derived svpc-psc-host-v1). If your host project ID
-- differs, replace it in the FROM clause of each query.
--
-- protocol: 6 = TCP, 17 = UDP, 1 = ICMP.
-- Each connection is logged twice (reporter SRC and DEST) — filter to one
-- before summing bytes/packets. bytes_sent/packets_sent are STRINGs (CAST).
-- The sink is folder-aggregated, so rows arrive from all four projects; the
-- src_project / dest_project columns show which project each side lives in.


-- 1) Recent flows, human-readable
SELECT
  timestamp,
  jsonPayload.src_instance.project_id  AS src_project,
  jsonPayload.dest_instance.project_id AS dest_project,
  jsonPayload.connection.src_ip    AS src_ip,
  jsonPayload.connection.dest_ip   AS dest_ip,
  jsonPayload.connection.dest_port AS dest_port,
  CASE CAST(jsonPayload.connection.protocol AS INT64)
    WHEN 6 THEN 'TCP' WHEN 17 THEN 'UDP' WHEN 1 THEN 'ICMP'
    ELSE CAST(jsonPayload.connection.protocol AS STRING) END AS protocol,
  jsonPayload.src_instance.vm_name  AS src_vm,
  jsonPayload.dest_instance.vm_name AS dest_vm,
  jsonPayload.src_vpc.subnetwork_name  AS src_subnet,
  jsonPayload.dest_vpc.subnetwork_name AS dest_subnet,
  CAST(jsonPayload.bytes_sent AS INT64) AS bytes
FROM `svpc-psc-host-v1.vpc_flow_logs.compute_googleapis_com_vpc_flows`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
  AND jsonPayload.reporter = 'SRC'
ORDER BY timestamp DESC
LIMIT 100;


-- 2) Verify east-west: web -> database on TCP 5432
SELECT
  jsonPayload.src_instance.vm_name  AS src_vm,
  jsonPayload.dest_instance.vm_name AS dest_vm,
  jsonPayload.connection.src_ip     AS src_ip,
  jsonPayload.connection.dest_ip    AS dest_ip,
  COUNT(*)                                   AS flow_records,
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS total_bytes
FROM `svpc-psc-host-v1.vpc_flow_logs.compute_googleapis_com_vpc_flows`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
  AND jsonPayload.reporter = 'SRC'
  AND CAST(jsonPayload.connection.protocol AS INT64) = 6
  AND CAST(jsonPayload.connection.dest_port AS INT64) = 5432
GROUP BY src_vm, dest_vm, src_ip, dest_ip
ORDER BY total_bytes DESC;


-- 3) Top talkers by bytes
SELECT
  jsonPayload.connection.src_ip    AS src_ip,
  jsonPayload.connection.dest_ip   AS dest_ip,
  jsonPayload.connection.dest_port AS dest_port,
  SUM(CAST(jsonPayload.bytes_sent AS INT64))   AS total_bytes,
  SUM(CAST(jsonPayload.packets_sent AS INT64)) AS total_packets
FROM `svpc-psc-host-v1.vpc_flow_logs.compute_googleapis_com_vpc_flows`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
  AND jsonPayload.reporter = 'SRC'
GROUP BY src_ip, dest_ip, dest_port
ORDER BY total_bytes DESC
LIMIT 25;


-- 4) Ingress to the web/API workload (published-service traffic)
SELECT
  jsonPayload.connection.src_ip     AS src_ip,
  jsonPayload.dest_instance.vm_name AS dest_vm,
  jsonPayload.connection.dest_port  AS dest_port,
  COUNT(*)                                   AS flow_records,
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS total_bytes
FROM `svpc-psc-host-v1.vpc_flow_logs.compute_googleapis_com_vpc_flows`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
  AND jsonPayload.reporter = 'DEST'
  AND jsonPayload.dest_vpc.subnetwork_name = 'prod-subnet'
GROUP BY src_ip, dest_vm, dest_port
ORDER BY total_bytes DESC;


-- 5) Flow volume by subnet pair
SELECT
  jsonPayload.src_vpc.subnetwork_name  AS src_subnet,
  jsonPayload.dest_vpc.subnetwork_name AS dest_subnet,
  COUNT(*)                                   AS flow_records,
  SUM(CAST(jsonPayload.bytes_sent AS INT64)) AS total_bytes
FROM `svpc-psc-host-v1.vpc_flow_logs.compute_googleapis_com_vpc_flows`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
  AND jsonPayload.reporter = 'SRC'
GROUP BY src_subnet, dest_subnet
ORDER BY total_bytes DESC;
