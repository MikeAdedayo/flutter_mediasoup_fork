import 'package:flutter_mediasoup/mediasoup_client/dtls_parameters.dart';
import 'package:sdp_transform/sdp_transform.dart';

extractDtlsParameters(dynamic sdp) {
    Map mediaObject = (sdp["media"].toList() ?? [])
      .firstWhere((media) => media['iceUfrag'] != null && media['port'] != 0, orElse: () => null);

    if (mediaObject == null) {
      throw("Error no actvie media object!");
    }

    Map fingerprint = mediaObject["fingerprint"] ?? sdp["fingerprint"];
    String role;

    switch (mediaObject["setup"])
    {
      case 'active':
        role = 'client';
        break;
      case 'passive':
        role = 'server';
        break;
      case 'actpass':
        role = 'auto';
        break;
    }

    DtlsParameters dtlsParameters = DtlsParameters.fromJson({
      "role": role,
      "fingerprints" :
      [
        {
          "algorithm" : fingerprint["type"],
          "value"     : fingerprint["hash"]
        }
      ]
    });

    return dtlsParameters;
  }

  extractRtpCapabilities(Map sdpObject) {
    // Map of RtpCodecParameters indexed by payload type.
    Map codecsMap  = Map();
    // Array of RtpHeaderExtensions.
    List headerExtensions = [];
    // Whether a m=audio/video section has been already found.
    bool gotAudio = false;
    bool gotVideo = false;

    for (Map m in sdpObject["media"]) {
      String kind = m["type"];

      switch (kind) {
        case 'audio': {
          if (gotAudio)
            continue;

          gotAudio = true;

          break;
        }
        case 'video': {
          if (gotVideo)
            continue;

          gotVideo = true;

          break;
        }
        default: {
          continue;
        }
      }

      // Get codecs.
      for (Map rtp in m["rtp"]) {
        Map codec = {
          "kind"                 : kind,
          "mimeType"             : "$kind/${rtp["codec"]}",
          "preferredPayloadType" : rtp["payload"],
          "clockRate"            : rtp["rate"],
          "channels"             : rtp["encoding"],
          "parameters"           : {},
          "rtcpFeedback"         : []
        };

        codecsMap[codec["preferredPayloadType"]] = codec;
      }

      // Get codec parameters.
      for (Map fmtp in (m["fmtp"] ?? [])) {
        Map _parameters = parse(fmtp["config"]);
        Map codec = codecsMap[fmtp["payload"]];

        if (codec == null)
          continue;

        Map parameters = Map();
        for (String key in _parameters.keys) {
          if (_parameters[key].length > 0) {
            parameters[key] = _parameters[key][0]["value"];
          }
        }

        // Specials case to convert parameter value to string.
        if (parameters != null && parameters['profile-level-id'] != null)
          parameters['profile-level-id'] = parameters['profile-level-id'];

        // codec["parameters"] = parameters;
      }

      // Get RTCP feedback for each codec.
      for (Map fb in (m["rtcpFb"] ?? [])) {
        Map codec = codecsMap[fb["payload"]];

        if (codec == null)
          continue;

        Map feedback = {
          "type"      : fb["type"],
          "parameter" : fb["subtype"]
        };

        if (feedback["parameter"] == null)
          feedback.remove("parameter");

        codec["rtcpFeedback"].add(feedback);
      }

      // Get RTP header extensions.
      for (Map ext in (m["ext"] ?? [])) {
        Map headerExtension = {
          "kind"        : kind,
          "uri"         : ext["uri"],
          "preferredId" : ext["value"]
        };

        headerExtensions.add(headerExtension);
      }
    }

    Map rtpCapabilities = {
      "codecs"           : codecsMap.keys.map((key) => codecsMap[key]).toList(),
      "headerExtensions" : headerExtensions
    };

    return rtpCapabilities;
  }

getCname(Map offerMediaObject) {
	Map ssrcCnameLine = (offerMediaObject["ssrcs"] ?? [])
		.firstWhere((line) => line["attribute"] == 'cname', orElse: () => null);

	if (ssrcCnameLine == null)
		return '';

	return ssrcCnameLine["value"];
}

applyCodecParameters({
		Map offerRtpParameters,
		Map answerMediaObject
	}) {
	for (Map codec in offerRtpParameters["codecs"]) {
		String mimeType = codec["mimeType"].toLowerCase();

		// Avoid parsing codec parameters for unhandled codecs.
		if (mimeType != 'audio/opus')
			continue;

		Map rtp = (answerMediaObject["rtp"] ?? [])
			.firstWhere((r) => r["payload"] == codec["payloadType"], orElse: () => null);

		if (rtp == null)
			continue;

		// Just in case.
		answerMediaObject["fmtp"] = answerMediaObject["fmtp"] ?? [];

		Map fmtp = answerMediaObject["fmtp"]
			.firstWhere((f) => f["payload"] == codec["payloadType"], orElse: () => null);

		if (fmtp == null) {
			fmtp = { "payload": codec["payloadType"], "config": '' };
			answerMediaObject["fmtp"].push(fmtp);
		}

		Map parameters = parseParams(fmtp["config"]);

		switch (mimeType) {
			case 'audio/opus': {
				int spropStereo = codec["parameters"]['sprop-stereo'];

				if (spropStereo != null)
					parameters["stereo"] = spropStereo > 0 ? 1 : 0;

				break;
			}
		}

		// Write the codec fmtp.config back.
		fmtp["config"] = '';

		for (String key in parameters.keys) {
			if (fmtp["config"].length > 0)
				fmtp["config"] += ';';

			fmtp["config"] += "$key=${parameters[key]}";
		}
	}
}