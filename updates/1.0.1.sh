#!/bin/bash

STATEMENT="CREATE TABLE vs_track (  id int(11) unsigned NOT NULL AUTO_INCREMENT,  url varchar(120) DEFAULT NULL,  time_viewed datetime DEFAULT NULL,  PRIMARY KEY (id)) ENGINE=InnoDB DEFAULT CHARSET=latin1;"
sudo mysql -D vspi_local -e "$STATEMENT"
echo "Added 'vs_track' table to 'vspi_local' database"