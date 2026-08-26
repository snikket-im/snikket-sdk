import { sqliteTest as test, expect } from "./browser-test";
import { sharedPersistenceTests } from "./persistence-tests";

sharedPersistenceTests(test);
