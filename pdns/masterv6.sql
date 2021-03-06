use powerdns;
INSERT INTO domains (name, master, last_check, type, notified_serial, `account`) VALUES ('example.com', NULL, NULL, 'MASTER', NULL, NULL);
SELECT id from domains WHERE name='example.com' INTO @domain_id;
INSERT INTO records (domain_id, name, type, content, ttl, prio, change_date, disabled, ordername, `auth`) VALUES
(@domain_id, 'example.com', 'SOA', 'ns0.example.com mail.gmail.com. 2018040600 3600 900 604800 86400', 86400, NULL, NULL, 0, NULL, 1),
(@domain_id, 'example.com', 'NS', 'ns0.example.com', 86400, 0, NULL, 0, NULL, 1),
(@domain_id, 'example.com', 'NS', 'ns1.example.com', 86400, 0, NULL, 0, NULL, 1),
(@domain_id, 'example.com', 'AAAA', 'placeAAAA', 86400, 0, NULL, 0, NULL, 1),
(@domain_id, 'ns0.example.com', 'AAAA', 'placeNS0v6', 86400, 0, NULL, 0, NULL, 1),
(@domain_id, 'ns1.example.com', 'AAAA', 'placeNS1v6', 86400, 0, NULL, 0, NULL, 1);
