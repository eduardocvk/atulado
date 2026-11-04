CREATE TABLE `devices` (
	`id` text PRIMARY KEY NOT NULL,
	`token_hash` text NOT NULL,
	`code_hash` text,
	`owner` text,
	`race` text,
	`expires` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `devices_token_hash_unique` ON `devices` (`token_hash`);--> statement-breakpoint
CREATE UNIQUE INDEX `devices_code_hash_unique` ON `devices` (`code_hash`);--> statement-breakpoint
CREATE TABLE `request_limits` (
	`key` text PRIMARY KEY NOT NULL,
	`count` integer NOT NULL,
	`expires` integer NOT NULL
);
--> statement-breakpoint
CREATE TABLE `messages` (
	`id` text PRIMARY KEY NOT NULL,
	`race` text NOT NULL,
	`name` text NOT NULL,
	`meters` integer NOT NULL,
	`duration` integer NOT NULL,
	`bytes` integer NOT NULL,
	`object_key` text NOT NULL,
	`sha` text NOT NULL,
	`ready` integer DEFAULT 0 NOT NULL,
	`created` integer NOT NULL,
	FOREIGN KEY (`race`) REFERENCES `races`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `messages_race` ON `messages` (`race`);--> statement-breakpoint
CREATE TABLE `races` (
	`id` text PRIMARY KEY NOT NULL,
	`owner` text NOT NULL,
	`name` text NOT NULL,
	`date` text NOT NULL,
	`meters` integer NOT NULL,
	`version` integer DEFAULT 1 NOT NULL,
	`invite_hash` text,
	`open` integer DEFAULT 1 NOT NULL,
	`surprise` integer DEFAULT 1 NOT NULL,
	`created` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `races_owner` ON `races` (`owner`);