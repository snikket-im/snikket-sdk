import { sqliteTest as test, expect } from "./browser-test";
import { sharedPersistenceTests } from "./persistence-tests";

test.describe("not webkit", () => {
	test.skip(
		({ browserName }) => browserName === "webkit",
		"Skip on webkit because the version in playwright lacks OPFS",
	);

	sharedPersistenceTests(test);
});
