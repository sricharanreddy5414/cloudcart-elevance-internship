-- Run this on the Task 2 MySQL RDS instance after it exists.
-- Do not run it on the EverShop PostgreSQL database.
-- The IAM user has no password. RDS expects the AWSAuthenticationPlugin.

CREATE USER IF NOT EXISTS cloudcart_iam IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';
ALTER USER cloudcart_iam REQUIRE SSL;
GRANT SELECT, INSERT, UPDATE, DELETE ON cloudcart_security.* TO cloudcart_iam;

-- The password user is the RDS-managed master user, or cloudcart_app.
-- Its password lives in Secrets Manager and is rotated.
-- Do not grant AWSAuthenticationPlugin to that same user.
-- On MySQL, IAM authentication is selected by the plugin above.
-- A user with this plugin does not log in with the rotated password.
