import "dart:core";

abstract class MediaSection {
	// SDP media object.
	Map mediaObject;

	// Whether this is Plan-B SDP.
	bool planB;

	MediaSection(Map data) {
    Map iceParameters = data["iceParameters"];
    List<Map> iceCandidates = data["iceCandidates"] ?? [];
    Map dtlsParameters = data["dtlsParameters"];
    planB = data["planB"] == true;

		mediaObject = {};

		if (iceParameters != null) {
			setIceParameters(iceParameters);
		}

		if (iceCandidates != null) {
			mediaObject["candidates"] = [];

			for (Map candidate in iceCandidates) {
				Map candidateObject = {};

				// mediasoup does mandates rtcp-mux so candidates component is always
				// RTP (1).
				candidateObject["component"] = 1;
				candidateObject["foundation"] = candidate["foundation"];
				candidateObject["ip"] = candidate["ip"];
				candidateObject["port"] = candidate["port"];
				candidateObject["priority"] = candidate["priority"];
				candidateObject["transport"] = candidate["protocol"];
				candidateObject["type"] = candidate['type'];
				if (candidate["tcpType"] != null) {
					candidateObject["tcptype"] = candidate["tcpType"];
        }

				mediaObject["candidates"].add(candidateObject);
			}

			mediaObject["endOfCandidates"] = 'end-of-candidates';
			mediaObject["iceOptions"] = 'renomination';
		}

		if (dtlsParameters != null) {
			setDtlsRole(dtlsParameters["role"]);
		}
	}

	setDtlsRole(String role);

	get mid => mediaObject["mid"];

	get closed => mediaObject["port"] == 0;

	getObject() => mediaObject;

	/**
	 * @param {RTCIceParameters} iceParameters
	 */
	setIceParameters(Map iceParameters) {
		mediaObject["iceUfrag"] = iceParameters["usernameFragment"];
		mediaObject["icePwd"] = iceParameters["password"];
	}

	disable() {
		mediaObject["direction"] = 'inactive';

    mediaObject.remove("ext");
    mediaObject.remove("ssrcs");
    mediaObject.remove("ssrcGroups");
    mediaObject.remove("simulcast");
    mediaObject.remove("simulcast_03");
    mediaObject.remove("rids");
	}

	close() {
		mediaObject["direction"] = 'inactive';

		mediaObject["port"] = 0;

    mediaObject.remove("ext");
    mediaObject.remove("ssrcs");
    mediaObject.remove("ssrcGroups");
    mediaObject.remove("simulcast");
    mediaObject.remove("simulcast_03");
    mediaObject.remove("rids");
    mediaObject.remove("extmapAllowMixed");
	}

  getCodecName(Map codec) {
    RegExp mimeTypeRegex = RegExp(r"^(audio|video)/(.+)", caseSensitive: true);
    Iterable<RegExpMatch> mimeTypeMatch = mimeTypeRegex.allMatches(codec["mimeType"]);

    if (mimeTypeMatch == null) {
      throw('invalid codec.mimeType');
    }

    return mimeTypeMatch.elementAt(0).group(2);
  }
}