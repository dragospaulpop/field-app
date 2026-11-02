CREATE TABLE `photo_queue` (
	`id` text PRIMARY KEY NOT NULL,
	`entrance_id` text NOT NULL,
	`local_uri` text NOT NULL,
	`remote_path` text NOT NULL,
	`state` text DEFAULT 'pending' NOT NULL,
	`attempts` integer DEFAULT 0 NOT NULL,
	`next_attempt_at` integer DEFAULT 0 NOT NULL,
	`last_error` text,
	`created_at` integer NOT NULL
);
