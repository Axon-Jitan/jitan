-- Jitan: seed data for the LOCAL, DISPOSABLE development database only.
--
-- Realistic but fake people and companies for testing onboarding, sign-in,
-- refusal, company scoping, Reset account access and QR recovery. The
-- passwords below are local fixtures (documented in README.md); they exist
-- nowhere else. Never load this file into an IT-managed database.
--
-- Fixed IDs so the README and manual tests can refer to them.

SET NAMES utf8mb4;

-- Companies
INSERT INTO tblCompany (companyID, companyName, companyActive, companyMFD) VALUES
  (1, 'Almeco', 1, 0),
  (2, 'PCA', 1, 0);

-- Employee types (tblGroup = Blue collar / White collar)
INSERT INTO tblGroup (groupID, groupName, groupActive, groupMFD) VALUES
  (1, 'White collar', 1, 0),
  (2, 'Blue collar', 1, 0);

-- Access roles (tblCredGroup). Names from the ERD documentation; the real
-- rows, levels and module mapping are IT's (CLARIFY-10/11).
INSERT INTO tblCredGroup (credGroupID, credGroupName, credGroupLevel, credGroupActive, credGroupMFD) VALUES
  (1, 'Employee', 1, 1, 0),
  (2, 'HR', 2, 1, 0),
  (3, 'Admin', 3, 1, 0);

-- Languages. English is built into the apps; its row only makes it
-- selectable like the others.
INSERT INTO tblLanguage (languageID, languageName, languageCode, languageActive, languageMFD) VALUES
  (1, 'English', 'en', 1, 0),
  (2, 'Nederlands', 'nl', 1, 0),
  (3, 'Français', 'fr', 1, 0),
  (4, 'Deutsch', 'de', 1, 0);

-- A few Dutch texts to see a database language take effect. Everything else
-- falls back to the built-in English.
INSERT INTO tblTranslation (languageID, translationUIName, translationUIText) VALUES
  (2, 'onboarding.password.title', 'Stel je wachtwoord in'),
  (2, 'onboarding.password.label', 'Wachtwoord'),
  (2, 'onboarding.password.confirm.label', 'Bevestig wachtwoord'),
  (2, 'onboarding.ready.title', 'Je bent klaar.'),
  (2, 'onboarding.ready.action', 'Start Jitan'),
  (2, 'home.greeting', 'Hallo, {name}'),
  (2, 'language.name.en', 'Engels'),
  (2, 'language.name.nl', 'Nederlands'),
  (2, 'language.name.fr', 'Frans'),
  (2, 'language.name.de', 'Duits');

-- Audit event types, named as Jitan's code names them (AuditEventType).
-- LOCAL ASSUMPTION: the real names are IT's (CLARIFY-11). Without these rows
-- events are still logged, only without a type link.
INSERT INTO tblEventType (eventTypeID, eventTypeName) VALUES
  (1, 'employee.created'),
  (2, 'employee.personal_qr.generated'),
  (3, 'employee.onboarding.completed'),
  (4, 'employee.password.changed'),
  (5, 'employee.access.reset'),
  (6, 'employee.company.assigned'),
  (7, 'employee.group.assigned'),
  (8, 'employee.credential_group.assigned'),
  (9, 'employee.language.changed'),
  (10, 'employee.company.removed'),
  (11, 'employee.group.removed'),
  (12, 'employee.onboarding_qr.generated'),
  (13, 'employee.recovery_qr.generated'),
  (14, 'employee.access.recovered');

-- People. userQRcode values are random (never derived from IDs or codes).
--  1 Hanne Claes      HR in Almeco + PCA, activated   (local password Hanne-Local-Dev-1)
--  2 Disan Ssebowa    Almeco, active, NOT activated   (userPassword NULL: onboarding)
--  3 Kevin De Vos     Almeco, active, activated       (local password Kevin-Local-Dev-1)
--  4 Fabian Peeters   Almeco, INACTIVE, activated     (local password Fabian-Local-Dev-1)
--  5 Sara Maes        Almeco, MFD, activated          (local password Sara-Local-Dev-1)
--  6 Thomas Vermeulen PCA only, active, NOT activated (company scoping)
INSERT INTO tblUser
  (userID, userName, userSurname, userEmail, cellphoneNumber, userCode, userQRcode, userPassword,
   userKioskMode, userPINCode, userActive, userMFD)
VALUES
  (1, 'Hanne', 'Claes', NULL, NULL, 'HCL', '9hCXVyef49_msLoccCm9Nh-aEvb2rXDs',
   '$argon2id$v=19$m=19456,t=2,p=1$mMXwcnowTA8j892ki4M0Jg$9CrY4XhVKvxhn5iZgeN0HuFweRcgQfEBsbNS/QSLgUE',
   0, NULL, 1, 0),
  (2, 'Disan', 'Ssebowa', NULL, '+32 470 00 00 01', 'SBW', '5xYTglqwzf36v9UidULWYleBWfwt7Cjp', NULL,
   0, NULL, 1, 0),
  (3, 'Kevin', 'De Vos', NULL, NULL, 'KDV', 'MvrbloqIf-j151FU_94120bzpkqi4K6o',
   '$argon2id$v=19$m=19456,t=2,p=1$FtEmzthX25hzsvw2JWaafw$XEH+7cL9rO2395fv3zQJJ6iLzM8Mr4oxGFkdbujdigs',
   0, NULL, 1, 0),
  (4, 'Fabian', 'Peeters', NULL, NULL, 'FPT', 'arLmzMjwoiD_9wfeXpfKFaZ9vs_jExUp',
   '$argon2id$v=19$m=19456,t=2,p=1$QN29ayQ+NqpTA3QOTKKL/w$ZQPRstg0UYlhwntl02+nyStFyprTYwpFSwfn558Hf3g',
   0, NULL, 0, 0),
  (5, 'Sara', 'Maes', NULL, NULL, 'SMA', 'ZYOtI-VXnKNJB7-4yl0Ow5sMukkdzpYk',
   '$argon2id$v=19$m=19456,t=2,p=1$GRcCLfke6vkKp2PH8ahmYA$aD9QN166X33+Xf2b+9xcB4aZXR3TdnZdJkL6Vc3847A',
   0, NULL, 1, 1),
  (6, 'Thomas', 'Vermeulen', NULL, NULL, 'TVM', '3Vk7txZEtMZtw_7ZkShSAkgpfmmcBDMo', NULL,
   0, NULL, 1, 0);

INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) VALUES
  (1, 1, 1, 0), (1, 2, 1, 0),
  (2, 1, 1, 0),
  (3, 1, 1, 0),
  (4, 1, 1, 0),
  (5, 1, 1, 0),
  (6, 2, 1, 0);

INSERT INTO tblUserGroup (userID, groupID, userGroupActive, userGroupMFD) VALUES
  (1, 1, 1, 0),
  (2, 1, 1, 0),
  (3, 1, 1, 0),
  (4, 2, 1, 0),
  (5, 2, 1, 0),
  (6, 2, 1, 0);

INSERT INTO tblUserCredGroup (userID, credGroupID) VALUES
  (1, 2),
  (2, 1), (3, 1), (4, 1), (5, 1), (6, 1);

-- Kevin already chose Dutch; Hanne English.
INSERT INTO tblUserLanguage (userID, languageID) VALUES
  (1, 1),
  (3, 2);
