import { faker } from "@faker-js/faker";

type MakeMessageOpts = {
	serverId?: string;
	serverIdBy?: string;
	localId?: string;
	senderId?: string;
	to?: any; // JID
	from?: any; // JID
	direction?: 0 | 1;
	sortId?: string;
	recipients?: string[];
	replyTo?: string[];
	text?: string;
	timestamp?: Date;
	versions?: any[];
};

type CorrectionProps = {
	text: string;
};

export function createFactories(borogove: any) {
	const message = ({
		serverId,
		serverIdBy,
		localId,
		senderId,
		to,
		from,
		direction,
		sortId,
		recipients,
		replyTo,
		text,
		timestamp,
		versions,
	}: MakeMessageOpts = {}) => {
		const toJID = to ?? borogove.JID.parse(faker.internet.email());
		const fromJID = from ?? borogove.JID.parse(faker.internet.email());

		const builder = new borogove.ChatMessageBuilder({
			serverId: serverId ?? crypto.randomUUID(),
			serverIdBy: serverIdBy ?? toJID.asString(),
			localId: localId ?? crypto.randomUUID(),
			senderId: senderId ?? fromJID.asString(),
			direction: direction ?? 0,
		});
		builder.sortId = sortId ?? crypto.randomUUID();
		builder.to = toJID;
		builder.from = fromJID;
		builder.recipients = recipients ?? [toJID];
		builder.replyTo = replyTo ?? [fromJID];
		builder.versions = versions ?? [];
		builder.text = text ?? faker.lorem.sentence();
		builder.timestamp = timestamp?.toISOString() ?? new Date().toISOString();

		return builder.build();
	};

	const corrections = (original: any, props: CorrectionProps[]) => {
		const originalTimestamp = new Date(original.timestamp).getTime();

		return props.map(({ text }, index) => {
			const versionTimestamp = new Date(originalTimestamp + index + 1);

			const version = message({
				to: original.to,
				from: original.from,
				text,
				timestamp: versionTimestamp,
			});

			return message({
				to: original.to,
				from: original.from,
				localId: original.localId,
				versions: [version],
				timestamp: versionTimestamp,
				text,
			});
		});
	};

	return { message, corrections };
}
