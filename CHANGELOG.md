## 1.2.2 (Development)

Features:
  - Make bastion port configurable 

## 1.2.1 (Development)

Features:
  - Updates for chef client compatability

## 1.2.0 (Development)

Features:
  - Berkshelf now supports bastion (`berks upload`)

## 1.1.1 (September 27, 2016)

Bugfixes:
  - Fixed the issue with `knife bastion status` plugin, when it sometimes failed to detect bastion host IP address

## 1.1.0 (August 30, 2016)

Changes:
  - Proxy code has been refactored to make it more generic, so it can be used to proxy any requests through bastion connection

Bugfixes:

## 1.0.0 (August 22, 2016)

Features:

  - Connect to bastion server via SSH and proxy all Chef requests through this connection
  - Knife plugins to monitor status, start and stop connections
