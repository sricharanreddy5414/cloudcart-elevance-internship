-- Run this on the Task 2 MySQL RDS instance after it exists.
-- Do not run it on the EverShop PostgreSQL database.
-- The IAM user has no password. RDS expects the AWSAuthenticationPlugin.

CREATE USER IF NOT EXISTS cloudcart_iam IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
ALTER USER cloudcart_iam REQUIRE SSL;
GRANT SELECT, INSERT, UPDATE, DELETE ON cloudcart_security.* TO cloudcart_iam;

-- cloudcart_admin is the RDS-managed master user.
-- Its password is created and rotated by RDS in Secrets Manager.
-- Do not grant AWSAuthenticationPlugin to cloudcart_admin.
-- Do not grant it to the same user as cloudcart_iam.
-- On MySQL, IAM authentication is selected by the plugin above.
-- A user with this plugin does not log in with the rotated password.
