import { sqliteTable, text, integer, index } from 'drizzle-orm/sqlite-core';
export const races = sqliteTable('races', {
    id: text('id').primaryKey(), owner: text('owner').notNull(), name: text('name').notNull(),
    date: text('date').notNull(), meters: integer('meters').notNull(), version: integer('version').notNull().default(1),
    inviteHash: text('invite_hash'), open: integer('open').notNull().default(1), surprise: integer('surprise').notNull().default(1),
    created: integer('created').notNull(),
}, t => [index('races_owner').on(t.owner)]);
export const messages = sqliteTable('messages', {
    id: text('id').primaryKey(), race: text('race').notNull().references(() => races.id),
    name: text('name').notNull(), meters: integer('meters').notNull(), duration: integer('duration').notNull(),
    bytes: integer('bytes').notNull(), key: text('object_key').notNull(), sha: text('sha').notNull(),
    ready: integer('ready').notNull().default(0), created: integer('created').notNull(),
}, t => [index('messages_race').on(t.race)]);
export const devices = sqliteTable('devices', {
    id: text('id').primaryKey(), tokenHash: text('token_hash').notNull().unique(),
    codeHash: text('code_hash').unique(), owner: text('owner'), race: text('race'), expires: integer('expires').notNull(),
});
export const limits = sqliteTable('request_limits', {
    key: text('key').primaryKey(), count: integer('count').notNull(), expires: integer('expires').notNull(),
});
