getRtpEncodings(offerMediaObject) {
	Set ssrcs = Set();

	for (Map line in offerMediaObject["ssrcs"] ?? []) {
		int ssrc = line["id"];

		ssrcs.add(ssrc);
	}

	if (ssrcs.length == 0)
		throw('no a=ssrc lines found');

	Map ssrcToRtxSsrc = Map();

	// First assume RTX is used.
	for (Map line in offerMediaObject["ssrcGroups"] ?? []) {
		if (line["semantics"] != 'FID')
			continue;

		 List<String> tokens = (line["ssrcs"] as String).split(" ");
     int  ssrc, rtxSsrc;
     if (tokens.length > 0) {
       ssrc = int.parse(tokens[0]);
     }
     if (tokens.length > 1) {
       rtxSsrc = int.parse(tokens[1]);
     }

		if (ssrcs.contains(ssrc)) {
			// Remove both the SSRC and RTX SSRC from the set so later we know that they
			// are already handled.
			ssrcs.remove(ssrc);
			ssrcs.remove(rtxSsrc);

			// Add to the map.
			ssrcToRtxSsrc[ssrc] = rtxSsrc;
		}
	}

	// If the set of SSRCs is not empty it means that RTX is not being used, so take
	// media SSRCs from there.
	for (int ssrc in ssrcs) {
		// Add to the map.
		ssrcToRtxSsrc[ssrc] = null;
	}

	List encodings = [];

	for (int ssrc in ssrcToRtxSsrc.keys) {
    int rtxSsrc = ssrcToRtxSsrc[ssrc];
		Map encoding = { "ssrc": ssrc };

		if (rtxSsrc != null)
			encoding["rtx"] = { "ssrc": rtxSsrc };

		encodings.add(encoding);
	}

	return encodings;
}