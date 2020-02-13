
import 'media_section.dart';

class AnswerMediaSection extends MediaSection {
	AnswerMediaSection(Map data) : super(data) {
		Map sctpParameters = data["sctpParameters"];
    Map offerMediaObject = data["offerMediaObject"];
		Map offerRtpParameters = data["offerRtpParameters"];
		Map answerRtpParameters = data["answerRtpParameters"];
		Map plainRtpParameters = data["plainRtpParameters"];
		Map codecOptions = data["codecOptions"];
		bool extmapAllowMixed = data["extmapAllowMixed"];

		mediaObject["mid"] = offerMediaObject["mid"];
		mediaObject["type"] = offerMediaObject["type"];
		mediaObject["protocol"] = offerMediaObject["protocol"];

		if (plainRtpParameters == null){
			mediaObject["connection"] = { "ip": '127.0.0.1', "version": 4 };
			mediaObject["port"] = 7;
		} else {
			mediaObject["connection"] = {
				"ip"      : plainRtpParameters["ip"],
				"version" : plainRtpParameters["ipVersion"]
			};
			mediaObject["port"] = plainRtpParameters["port"];
		}

		switch (offerMediaObject["type"]) {
			case 'audio':
			case 'video': {
				mediaObject["direction"] = 'recvonly';
				mediaObject["rtp"] = [];
				mediaObject["rtcpFb"] = [];
				mediaObject["fmtp"] = [];

				for (Map codec in answerRtpParameters["codecs"]) {
					Map rtp = {
						"payload" : codec["payloadType"],
						"codec"   : getCodecName(codec),
						"rate"    : codec["clockRate"]
					};

					if (codec["channels"] != null && codec["channels"] > 1)
						rtp["encoding"] = codec["channels"];

					mediaObject["rtp"].add(rtp);

					Map codecParameters = Map.from(codec["parameters"] ?? {});

					if (codecOptions != null) {
            bool opusStereo = codecOptions["opusStereo"];
            bool opusFec = codecOptions["opusStereo"];
            bool opusDtx = codecOptions["opusStereo"];
            dynamic opusMaxPlaybackRate = codecOptions["opusStereo"];
            dynamic opusPtime = codecOptions["opusStereo"];
            dynamic videoGoogleStartBitrate = codecOptions["opusStereo"];
            dynamic videoGoogleMaxBitrate = codecOptions["opusStereo"];
            dynamic videoGoogleMinBitrate = codecOptions["opusStereo"];

						Map offerCodec = (offerRtpParameters["codecs"] as List)
							.firstWhere((c) => c["payloadType"] == codec["payloadType"]);

						switch (codec["mimeType"].toLowerCase()) {
							case 'audio/opus': {
								if (opusStereo != null) {
									offerCodec["parameters"]['sprop-stereo'] = opusStereo ? 1 : 0;
									codecParameters["stereo"] = opusStereo ? 1 : 0;
								}

								if (opusFec != null) {
									offerCodec["parameters"]["useinbandfec"] = opusFec ? 1 : 0;
									codecParameters["useinbandfec"] = opusFec ? 1 : 0;
								}

								if (opusDtx != null) {
									offerCodec["parameters"]["usedtx"] = opusDtx ? 1 : 0;
									codecParameters["usedtx"] = opusDtx ? 1 : 0;
								}

								if (opusMaxPlaybackRate != null)
								{
									codecParameters["maxplaybackrate"] = opusMaxPlaybackRate;
								}

								if (opusPtime != null) {
									offerCodec["parameters"]["ptime"] = opusPtime;
									codecParameters["ptime"] = opusPtime;
								}

								break;
							}

							case 'video/vp8':
							case 'video/vp9':
							case 'video/h264':
							case 'video/h265':
							{
								if (videoGoogleStartBitrate != null)
									codecParameters['x-google-start-bitrate'] = videoGoogleStartBitrate;

								if (videoGoogleMaxBitrate != null)
									codecParameters['x-google-max-bitrate'] = videoGoogleMaxBitrate;

								if (videoGoogleMinBitrate != null)
									codecParameters['x-google-min-bitrate'] = videoGoogleMinBitrate;

								break;
							}
						}
					}

					Map fmtp = {
						"payload" : codec["payloadType"],
						"config"  : ''
					};

					for (String key in codecParameters.keys) {
						if (fmtp["config"] != null && fmtp["config"].length > 0) {
							fmtp["config"] += ';';
            }

						fmtp["config"] += "$key=${codecParameters[key]}";
					}

					if (fmtp["config"] != null && fmtp["config"].length > 0) {
						mediaObject["fmtp"].add(fmtp);
          }

					for (Map fb in codec["rtcpFeedback"]) {
						mediaObject["rtcpFb"].add({
								"payload" : codec["payloadType"],
								"type"    : fb["type"],
								"subtype" : fb["parameter"]
							});
					}
				}

				mediaObject["payloads"] = answerRtpParameters["codecs"]
          .where((codec) => codec["payloadType"] != null)
					.map((codec) => codec["payloadType"])
					.join(' ');

				mediaObject["ext"] = [];

				for (Map ext in answerRtpParameters["headerExtensions"]) {
					// Don't add a header extension if not present in the offer.
					bool found = (offerMediaObject["ext"] as List ?? [])
						.where((localExt) => localExt["uri"] == ext["uri"])
            .length > 0;

					if (!found) {
						continue;
          }

					mediaObject["ext"].add({
							"uri"   : ext["uri"],
							"value" : ext["id"]
						});
				}

				// Allow both 1 byte and 2 bytes length header extensions.
				if (
					extmapAllowMixed &&
					offerMediaObject["extmapAllowMixed"] == 'extmap-allow-mixed'
				)
				{
					mediaObject["extmapAllowMixed"] = 'extmap-allow-mixed';
				}

				// Simulcast.
				if (offerMediaObject.containsKey("simulcast")) {
					mediaObject["simulcast"] = {
						"dir1"  : 'recv',
						"list1" : offerMediaObject["simulcast"]["list1"]
					};

					mediaObject["rids"] = [];

					for (Map rid in (offerMediaObject["rids"] ?? [])) {
						if (rid["direction"] != 'send')
							continue;

						mediaObject["rids"].add({
								"id"        : rid["id"],
								"direction" : 'recv'
							});
					}
				}
				// Simulcast (draft version 03).
				else if (offerMediaObject.containsKey("simulcast_03")) {
					// eslint-disable-next-line camelcase, @typescript-eslint/camelcase
					mediaObject["simulcast_03"] = {
						"value" : offerMediaObject["simulcast_03"]["value"].replaceAll('send', 'recv')
					};

					mediaObject["rids"] = [];

					for (Map rid in (offerMediaObject["rids"] ?? [])) {
						if (rid["direction"] != 'send') {
							continue;
            }

						mediaObject["rids"].add({
								"id"        : rid["id"],
								"direction" : 'recv'
							});
					}
				}

				mediaObject["rtcpMux"] = 'rtcp-mux';
				mediaObject["rtcpRsize"] = 'rtcp-rsize';

				if (planB && mediaObject["type"] == 'video')
					mediaObject["xGoogleFlag"] = 'conference';

        break;
      }

			case 'application': {
				// New spec.
				if (offerMediaObject["sctpPort"] is num) {
					mediaObject["payloads"] = 'webrtc-datachannel';
					mediaObject["sctpPort"] = sctpParameters["port"];
					mediaObject["maxMessageSize"] = sctpParameters["maxMessageSize"];
				}
				// Old spec.
				else if (offerMediaObject["sctpmap"] != null) {
					mediaObject["payloads"] = sctpParameters["port"];
					mediaObject["sctpmap"] = {
						"app"            : 'webrtc-datachannel',
						"sctpmapNumber"  : sctpParameters["port"],
						"maxMessageSize" : sctpParameters["maxMessageSize"]
					};
				}
      }
		}
	}

	/**
	 * @param {String} role
	 */
	setDtlsRole(role) {
		switch (role)
		{
			case 'client':
				mediaObject["setup"] = 'active';
				break;
			case 'server':
				mediaObject["setup"] = 'passive';
				break;
			case 'auto':
				mediaObject["setup"] = 'actpass';
				break;
		}
	}
}