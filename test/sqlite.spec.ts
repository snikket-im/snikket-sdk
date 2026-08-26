import { sqliteTest } from "./browser-test";
import { sharedPersistenceTests } from "./persistence-tests";

sharedPersistenceTests(sqliteTest);
