/**
 * Generate RTP parameters of the given kind suitable for the remote SDP answer.
 */
 getSendingRemoteRtpParameters(kind, Map extendedRtpCapabilities) {
	Map rtpParameters = {
		"mid"              : null,
		"codecs"           : [],
		"headerExtensions" : [],
		"encodings"        : [],
		"rtcp"             : {}
	};

	for (Map extendedCodec in extendedRtpCapabilities["codecs"]) {
		if (extendedCodec["kind"] != kind)
			continue;

		Map codec = {
			"mimeType"     : extendedCodec["mimeType"],
			"payloadType"  : extendedCodec["localPayloadType"],
			"clockRate"    : extendedCodec["clockRate"],
			"channels"     : extendedCodec["channels"],
			"parameters"   : extendedCodec["remoteParameters"],
			"rtcpFeedback" : extendedCodec["rtcpFeedback"]
		};

		rtpParameters["codecs"].add(codec);

		// Add RTX codec.
		if (extendedCodec.containsKey("localRtxPayloadType") && extendedCodec["localRtxPayloadType"] != null) {
			Map rtxCodec = {
				"mimeType"    : "${extendedCodec["kind"]}/rtx",
				"payloadType" : extendedCodec["localRtxPayloadType"],
				"clockRate"   : extendedCodec["clockRate"],
				"channels"    : 1,
				"parameters"  : {
					"apt" : extendedCodec["localPayloadType"]
				},
				"rtcpFeedback" : []
			};

			rtpParameters["codecs"].add(rtxCodec);
		}

		// NOTE: We assume a single media codec plus an optional RTX codec.
		break;
	}

	for (Map extendedExtension in extendedRtpCapabilities["headerExtensions"]) {
		// Ignore RTP extensions of a different kind and those not valid for sending.
		if (
			(extendedExtension["kind"] != null && extendedExtension["kind"] != kind) ||
			(
				extendedExtension["direction"] != 'sendrecv' &&
				extendedExtension["direction"] != 'sendonly'
			)
		) {
			continue;
		}

		Map ext = {
			"uri"        : extendedExtension["uri"],
			"id"         : extendedExtension["sendId"],
			"encrypt"    : extendedExtension["encrypt"],
			"parameters" : {}
		};

		rtpParameters["headerExtensions"].add(ext);
	}

	// Reduce codecs' RTCP feedback. Use Transport-CC if available, REMB otherwise.
	if (
		(rtpParameters["headerExtensions"] as List).where((ext) => (
			ext["uri"] == 'http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01'
		)).toList().length > 0
	) {
		for (Map codec in rtpParameters["codecs"]) {
			codec["rtcpFeedback"] = (codec["rtcpFeedback"] ?? [])
				.where((fb) => fb["type"] != 'goog-remb').toList();
		}
	} else if (
		(rtpParameters["headerExtensions"] as List).where((ext) => (
			ext["uri"] == 'http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time'
		)).toList().length > 0
	) {
		for (Map codec in rtpParameters["codecs"]) {
			codec["rtcpFeedback"] = (codec["rtcpFeedback"] ?? [])
				.where((fb) => fb["type"] != 'transport-cc').toList();
		}
	} else {
		for (Map codec in rtpParameters["codecs"]) {
			codec["rtcpFeedback"] = (codec["rtcpFeedback"] ?? [])
				.where((fb) => (
					fb["type"] != 'transport-cc' &&
					fb["type"] != 'goog-remb'
				)).toList();
		}
	}

	return rtpParameters;
}

isRtxCodec(Map codec) => RegExp(r'.+\/rtx$', caseSensitive: true).hasMatch(codec["mimeType"]);

bool matchCodecs(Map aCodec, Map bCodec, { strict = false, modify = false }) {
	String aMimeType = aCodec["mimeType"].toLowerCase();
	String bMimeType = bCodec["mimeType"].toLowerCase();

	if (aMimeType != bMimeType)
		return false;

	if (aCodec["clockRate"] != bCodec["clockRate"])
		return false;

	if (aCodec["channels"] != bCodec["channels"])
		return false;

	// Per codec special checks.
	switch (aMimeType) {
		case 'video/h264': {
			num aPacketizationMode = aCodec["parameters"]['packetization-mode'] ?? 0;
			num bPacketizationMode = bCodec["parameters"]['packetization-mode'] ?? 0;

			if (aPacketizationMode != bPacketizationMode)
				return false;

			// If strict matching check profile-level-id.
      // TODO: support strict checking
			// if (strict) {
			// 	if (!h264.isSameProfile(aCodec.parameters, bCodec.parameters))
			// 		return false;

			// 	let selectedProfileLevelId;

			// 	try
			// 	{
			// 		selectedProfileLevelId =
			// 			h264.generateProfileLevelIdForAnswer(aCodec.parameters, bCodec.parameters);
			// 	}
			// 	catch (error)
			// 	{
			// 		return false;
			// 	}

			// 	if (modify)
			// 	{
			// 		if (selectedProfileLevelId)
			// 			aCodec.parameters['profile-level-id'] = selectedProfileLevelId;
			// 		else
			// 			delete aCodec.parameters['profile-level-id'];
			// 	}
			// }

			break;
		}

		case 'video/vp9': {
			// If strict matching check profile-id.
			if (strict) {
			  num aProfileId = aCodec["parameters"]['profile-id'] ?? 0;
				num bProfileId = bCodec["parameters"]['profile-id'] ?? 0;

				if (aProfileId != bProfileId)
					return false;
			}

			break;
		}
	}

	return true;
}

bool matchHeaderExtensions( Map aExt, Map bExt) {
	if (aExt.containsKey("kind") && bExt.containsKey("kind") && aExt["kind"] != bExt["kind"])
		return false;

	if (aExt["uri"] != bExt["uri"])
		return false;

	return true;
}

getExtendedRtpCapabilities(localCaps, remoteCaps) {
	Map extendedRtpCapabilities = {
		"codecs"           : [],
		"headerExtensions" : []
	};

	// Match media codecs and keep the order preferred by remoteCaps.
	for (Map remoteCodec in remoteCaps["codecs"] ?? []) {
		if (isRtxCodec(remoteCodec))
			continue;

		Map matchingLocalCodec = (localCaps["codecs"] ?? [])
			.firstWhere((localCodec) => (
				matchCodecs(localCodec, remoteCodec, strict: true, modify: true ))
			, orElse: () => null);

		if (matchingLocalCodec == null)
			continue;

		Map extendedCodec = {
			"mimeType"             : matchingLocalCodec["mimeType"],
			"kind"                 : matchingLocalCodec["kind"],
			"clockRate"            : matchingLocalCodec["clockRate"],
			"channels"             : matchingLocalCodec["channels"],
			"localPayloadType"     : matchingLocalCodec["preferredPayloadType"],
			"localRtxPayloadType"  : null,
			"remotePayloadType"    : remoteCodec["preferredPayloadType"],
			"remoteRtxPayloadType" : null,
			"localParameters"      : matchingLocalCodec["parameters"],
			"remoteParameters"     : remoteCodec["parameters"],
			"rtcpFeedback"         : reduceRtcpFeedback(matchingLocalCodec, remoteCodec)
		};

		extendedRtpCapabilities["codecs"].add(extendedCodec);
	}

	// Match RTX codecs.
	for (Map extendedCodec in extendedRtpCapabilities["codecs"]) {
		Map matchingLocalRtxCodec = localCaps["codecs"]
			.firstWhere((localCodec) => (
				isRtxCodec(localCodec) &&
				localCodec["parameters"]["apt"] == extendedCodec["localPayloadType"]
			), orElse: () => null);

		Map matchingRemoteRtxCodec = remoteCaps["codecs"]
			.firstWhere((remoteCodec) => (
				isRtxCodec(remoteCodec) &&
				remoteCodec["parameters"]["apt"] == extendedCodec["remotePayloadType"]
			), orElse: () => null);

		if (matchingLocalRtxCodec != null && matchingRemoteRtxCodec != null) {
			extendedCodec["localRtxPayloadType"] = matchingLocalRtxCodec["preferredPayloadType"];
			extendedCodec["remoteRtxPayloadType"] = matchingRemoteRtxCodec["preferredPayloadType"];
		}
	}

	// Match header extensions.
	for (Map remoteExt in remoteCaps["headerExtensions"]) {
		Map matchingLocalExt = localCaps["headerExtensions"]
			.firstWhere((localExt) => matchHeaderExtensions(localExt, remoteExt), orElse: () => null);

		if (matchingLocalExt == null)
			continue;

		// TODO: Must do stuff for encrypted extensions.

		Map extendedExt = {
			"kind"      : remoteExt["kind"],
			"uri"       : remoteExt["uri"],
			"sendId"    : matchingLocalExt["preferredId"],
			"recvId"    : remoteExt["preferredId"],
			"encrypt"   : matchingLocalExt["preferredEncrypt"],
			"direction" : 'sendrecv'
		};

		switch (remoteExt["direction"]) {
			case 'sendrecv':
				extendedExt["direction"] = 'sendrecv';
				break;
			case 'recvonly':
				extendedExt["direction"] = 'sendonly';
				break;
			case 'sendonly':
				extendedExt["direction"] = 'recvonly';
				break;
			case 'inactive':
				extendedExt["direction"] = 'inactive';
				break;
		}

		extendedRtpCapabilities["headerExtensions"].add(extendedExt);
	}

	return extendedRtpCapabilities;
}

/**
 * Generate RTP capabilities for receiving media based on the given extended
 * RTP capabilities.
 */
getRecvRtpCapabilities(Map extendedRtpCapabilities) {
	Map rtpCapabilities =
	{
		"codecs"           : [],
		"headerExtensions" : []
	};

	for (Map extendedCodec in extendedRtpCapabilities["codecs"]) {
		Map codec = {
			"mimeType"             : extendedCodec["mimeType"],
			"kind"                 : extendedCodec["kind"],
			"preferredPayloadType" : extendedCodec["remotePayloadType"],
			"clockRate"            : extendedCodec["clockRate"],
			"channels"             : extendedCodec["channels"],
			"parameters"           : extendedCodec["localParameters"],
			"rtcpFeedback"         : extendedCodec["rtcpFeedback"]
		};

		rtpCapabilities["codecs"].add(codec);

		// Add RTX codec.
		if (extendedCodec["remoteRtxPayloadType"] == null)
			continue;

		Map rtxCodec = {
			"mimeType"             : "${extendedCodec["kind"]}/rtx",
			"kind"                 : extendedCodec["kind"],
			"preferredPayloadType" : extendedCodec["remoteRtxPayloadType"],
			"clockRate"            : extendedCodec["clockRate"],
			"channels"             : 1,
			"parameters"           : {
				"apt" : extendedCodec["remotePayloadType"]
			},
			"rtcpFeedback" : []
		};

		rtpCapabilities["codecs"].add(rtxCodec);

		// TODO: In the future, we need to add FEC, CN, etc, codecs.
	}

	for (Map extendedExtension in extendedRtpCapabilities["headerExtensions"]) {
		// Ignore RTP extensions not valid for receiving.
		if (
			extendedExtension["direction"] != 'sendrecv' &&
			extendedExtension["direction"] != 'recvonly'
		) {
			continue;
		}

		Map ext = {
			"kind"             : extendedExtension["kind"],
			"uri"              : extendedExtension["uri"],
			"preferredId"      : extendedExtension["recvId"],
			"preferredEncrypt" : extendedExtension["encrypt"],
			"direction"        : extendedExtension["direction"]
		};

		rtpCapabilities["headerExtensions"].add(ext);
	}

	return rtpCapabilities;
}

isEmpty(String val) {
  return val == null || val.length == 0;
}

reduceRtcpFeedback(Map codecA, Map codecB) {
	List reducedRtcpFeedback = [];

	for (Map aFb in codecA["rtcpFeedback"] ?? []) {
		Map matchingBFb = (codecB["rtcpFeedback"] ?? [])
			.firstWhere((bFb) => (
				bFb["type"] == aFb["type"] &&
				(bFb["parameter"] == aFb["parameter"] || (isEmpty(bFb["parameter"]) && isEmpty(aFb["parameter"])))
			));

		if (matchingBFb != null)
			reducedRtcpFeedback.add(matchingBFb);
	}

	return reducedRtcpFeedback;
}