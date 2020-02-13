
import 'media_section.dart';

class OfferMediaSection extends MediaSection {
	OfferMediaSection(data) : super(data) {
    Map sctpParameters = data["sctpParameters"];
    Map plainRtpParameters = data["plainRtpParameters"];
		String mid = data["mid"];
		String kind = data["kind"];
		Map offerRtpParameters = data["offerRtpParameters"];
		String streamId = data["streamId"];
		String trackId = data["trackId"];
    bool oldDataChannelSpec = data["oldDataChannelSpec"];

		mediaObject["mid"] = mid.toString();
		mediaObject["type"] = kind;

		if (plainRtpParameters == null) {
			mediaObject["connection"] = { "ip": '127.0.0.1', "version": 4 };

			if (sctpParameters == null) {
				mediaObject["protocol"] = 'UDP/TLS/RTP/SAVPF';
      } else {
				mediaObject["protocol"] = 'UDP/DTLS/SCTP';
      }

			mediaObject["port"] = 7;
		} else {
			mediaObject["connection"] = {
				"ip"      : plainRtpParameters["ip"],
				"version" : plainRtpParameters["ipVersion"]
			};
			mediaObject["protocol"] = 'RTP/AVP';
			mediaObject["port"] = plainRtpParameters["port"];
		}

		switch (kind) {
			case 'audio':
			case 'video': {
				mediaObject["direction"] = 'sendonly';
				mediaObject["rtp"] = [];
				mediaObject["rtcpFb"] = [];
				mediaObject["fmtp"] = [];

				if (!planB) {
					mediaObject["msid"] = "${streamId ?? '-'} $trackId";
        }

				for (Map codec in offerRtpParameters["codecs"]) {
					Map rtp = {
						"payload" : codec["payloadType"],
						"codec"   : getCodecName(codec),
						"rate"    : codec["clockRate"]
					};

					if (codec["channels"] != null && codec["channels"] > 1) {
						rtp["encoding"] = codec["channels"];
          }

					mediaObject["rtp"].add(rtp);

					Map fmtp = {
						"payload" : codec["payloadType"],
						"config"  : ''
					};

					for (String key in codec["parameters"].keys) {
						if (fmtp["config"].length > 0) {
							fmtp["config"] += ';';
            }

						fmtp["config"] += "$key=${codec["parameters"][key]}";
					}

					if (fmtp["config"] != null) {
						mediaObject["fmtp"].add(fmtp);
          }

					for (Map fb in codec["rtcpFeedback"]) {
						mediaObject["rtcpFb"].add( {
								"payload" : codec["payloadType"],
								"type"    : fb["type"],
								"subtype" : fb["parameter"]
							});
					}
				}

				mediaObject["payloads"] = offerRtpParameters["codecs"]
					.map((codec) => codec["payloadType"])
					.join(' ');

				mediaObject["ext"] = [];

				for (Map ext in offerRtpParameters["headerExtensions"])
				{
					mediaObject["ext"].add({
							"uri"   : ext["uri"],
							"value" : ext["id"]
						});
				}

				mediaObject["rtcpMux"] = 'rtcp-mux';
				mediaObject["rtcpRsize"] = 'rtcp-rsize';

				Map encoding = offerRtpParameters["encodings"][0];
				int ssrc = encoding["ssrc"];
				int rtxSsrc = (encoding["rtx"] != null && encoding["rtx"]["ssrc"] != null)
					? encoding["rtx"]["ssrc"]
					: null;

				mediaObject["ssrcs"] = [];
				mediaObject["ssrcGroups"] = [];

				if (offerRtpParameters["rtcp"]["cname"] != null) {
					mediaObject["ssrcs"].add(
						{
							"id"        : ssrc,
							"attribute" : 'cname',
							"value"     : offerRtpParameters["rtcp"]["cname"]
						});
				}

				if (planB) {
					mediaObject["ssrcs"].add({
							"id"        : ssrc,
							"attribute" : 'msid',
							"value"     : "${streamId ?? '-'} $trackId"
						});
				}

				if (rtxSsrc != null) {
					if (offerRtpParameters["rtcp"]["cname"] != null) {
						mediaObject["ssrcs"].add( {
								"id"        : rtxSsrc,
								"attribute" : 'cname',
								"value"     : offerRtpParameters["rtcp"]["cname"]
							});
					}

					if (planB) {
						mediaObject["ssrcs"].add({
								"id"        : rtxSsrc,
								"attribute" : 'msid',
								"value"     : "${streamId ?? '-'} $trackId"
							});
					}

					// Associate original and retransmission SSRCs.
					mediaObject["ssrcGroups"].add({
							"semantics" : 'FID',
							"ssrcs"     : "$ssrc $rtxSsrc"
						});
				}

				break;
			}

			case 'application': {
				// New spec.
				if (!oldDataChannelSpec != null) {
					mediaObject["payloads"] = 'webrtc-datachannel';
					mediaObject["sctpPort"] = sctpParameters["port"];
					mediaObject["maxMessageSize"] = sctpParameters["maxMessageSize"];
				}
				// Old spec.
				else {
					mediaObject["payloads"] = sctpParameters["port"];
					mediaObject["sctpmap"] = {
						"app"            : 'webrtc-datachannel',
						"sctpmapNumber"  : sctpParameters["port"],
						"maxMessageSize" : sctpParameters["maxMessageSize"]
					};
				}

				break;
			}
		}
	}

	/**
	 * @param {String} role
	 */
	setDtlsRole(String role) {
		// Always 'actpass'.
		mediaObject["setup"] = 'actpass';
	}

	planBReceive(data) {
    Map offerRtpParameters = data["offerRtpParameters"];
    String streamId = data["streamId"];
    String trackId = data["trackId"];
		Map encoding = offerRtpParameters["encodings"][0];
		String ssrc = encoding["ssrc"];
		String rtxSsrc = (encoding["rtx"] != null && encoding["rtx"]["ssrc"] != null)
			? encoding["rtx"]["ssrc"]
			: null;

		if (offerRtpParameters["rtcp"]["cname"]) {
			mediaObject["ssrcs"].add({
					"id"        : ssrc,
					"attribute" : 'cname',
					"value"     : offerRtpParameters["rtcp"]["cname"]
				});
		}

		mediaObject["ssrcs"].add({
				"id"        : ssrc,
				"attribute" : 'msid',
				"value"     : "${streamId ?? '-'} $trackId"
			});

		if (rtxSsrc != null) {
			if (offerRtpParameters["rtcp"]["cname"]) {
				mediaObject["ssrcs"].add({
						"id"        : rtxSsrc,
						"attribute" : 'cname',
						"value"     : offerRtpParameters["rtcp"]["cname"]
					});
			}

			mediaObject["ssrcs"].add({
					"id"        : rtxSsrc,
					"attribute" : 'msid',
					"value"     : "${streamId ?? '-'} $trackId"
				});

			// Associate original and retransmission SSRCs.
			mediaObject["ssrcGroups"].add({
					"semantics" : 'FID',
					"ssrcs"     : "$ssrc $rtxSsrc"
				});
		}
	}

	planBStopReceiving(offerRtpParameters) {
		Map encoding = offerRtpParameters["encodings"][0];
		String ssrc = encoding["ssrc"];
		String rtxSsrc = (encoding["rtx"] != null && encoding["rtx"]["ssrc"] != null)
			? encoding["rtx"]["ssrc"]
			: null;

		mediaObject["ssrcs"] = mediaObject["ssrcs"]
			.filter((s) => s["id"] != ["ssrc"] && s["id"] != ["rtxSsrc"]);

		if (rtxSsrc != null) {
			mediaObject["ssrcGroups"] = mediaObject["ssrcGroups"]
				.filter((group) => group["ssrcs"] != "$ssrc $rtxSsrc");
		}
	}
}