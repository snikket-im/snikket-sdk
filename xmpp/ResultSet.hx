package xmpp;

typedef ResultSetPageRequest = {
	var ?before : String; // Set to request the page before a given id (or empty string to request the very last page)
	var ?after : String; // Set to request the page after a given id
	var ?limit : String; // Request a limit on the number of items returned in the page
};

typedef ResultSetPageResult = {
	var first : String; // The RSM id of the first item in this page
	var last : String; // The RSM id of the last item in this page
	var ?index : Int; // The position (within 'count') of the first item in this page
	var ?count : Int; // Count of the *total* items, not the items in the page
};
