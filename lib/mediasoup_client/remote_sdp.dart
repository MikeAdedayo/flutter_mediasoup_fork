

import 'package:sdp_transform/sdp_transform.dart';

import 'answer_media_section.dart';
import 'dtls_parameters.dart';
import 'ice_candidate.dart';
import 'media_section.dart';
import 'offer_media_section.dart';

class RemoteSdp {
	// Remote ICE parameters.
	Map _iceParameters;

	// Remote ICE candidates.
	List<IceCandidate> _iceCandidates = [];

	// Remote DTLS parameters.
	DtlsParameters _dtlsParameters;

	// Remote SCTP parameters.
	Map _sctpParameters;

	// Parameters for plain RTP (no SRTP nor DTLS no BUNDLE). Fields:
	// @type {Object}
	//
	// Fields:
	// @param {String} ip
	// @param {Number} ipVersion - 4 or 6.
	// @param {Number} port
	Map _plainRtpParameters;

	// Whether this is Plan-B SDP.
	bool _planB;

	// MediaSection instances indexed by MID.
  Map<String, dynamic> _mediaSections = new Map();

	// First MID.
	String _firstMid;

	// SDP object.
	Map _sdpObject;

	RemoteSdp(
		{
			iceParameters,
			iceCandidates,
			dtlsParameters,
			sctpParameters,
			plainRtpParameters,
			planB = false
		}
	)
	{
		_iceParameters = iceParameters;
		_iceCandidates = iceCandidates;
		_dtlsParameters = dtlsParameters;
		_sctpParameters = sctpParameters;
		_plainRtpParameters = plainRtpParameters;
		_planB = planB;
		_sdpObject ={
			"version" : 0,
			"origin"  : {
				"address"        : '0.0.0.0',
				"ipVer"          : 4,
				"netType"        : 'IN',
				"sessionId"      : 10000,
				"sessionVersion" : 0,
				"username"       : 'mediasoup-client'
			},
			"name"   : '-',
			"timing" : { "start": 0, "stop": 0 },
			"media"  : []
		};

		// If ICE parameters are given, add ICE-Lite indicator.
		if (iceParameters != null && iceParameters["iceLite"]) {
			_sdpObject["icelite"] = 'ice-lite';
		}

		// If DTLS parameters are given assume WebRTC and BUNDLE.
		if (dtlsParameters != null) {
			_sdpObject["msidSemantic"] = { "semantic": 'WMS', "token": '*' };

			// NOTE: We take the latest fingerprint.
			num numFingerprints = _dtlsParameters["fingerprints"].length;

			_sdpObject["fingerprint"] = {
				"type" : dtlsParameters["fingerprints"][numFingerprints - 1]["algorithm"],
				"hash" : dtlsParameters["fingerprints"][numFingerprints - 1]["value"]
			};

			_sdpObject["groups"] = [ { "type": 'BUNDLE', "mids": '' } ];
		}

		// If there are plain parameters override SDP origin.
		if (plainRtpParameters != null) {
			_sdpObject["origin"]["address"] = plainRtpParameters["ip"];
			_sdpObject["origin"]["ipVer"] = plainRtpParameters["ipVersion"];
		}
	}

	updateIceParameters(iceParameters) {
		_iceParameters = iceParameters;
		_sdpObject["icelite"] = iceParameters["iceLite"] ? 'ice-lite' : null;

		for (String mediaSection in _mediaSections.keys) {
			_mediaSections[mediaSection].setIceParameters(iceParameters);
		}
	}

	updateDtlsRole(String role){
		_dtlsParameters["role"] = role;

		for (String mediaSection in _mediaSections.keys) {
			_mediaSections[mediaSection].setDtlsRole(role);
		}
	}

	getNextMediaSectionIdx() {
		num idx = -1;

		// If a closed media section is found, return its index.
		for (String mediaSection in _mediaSections.keys) {
			idx++;

			if (_mediaSections[mediaSection].closed) {
				return { "idx": idx, "reuseMid": _mediaSections[mediaSection]["mid"] };
      }
		}

		// If no closed media section is found, return next one.
		return { "idx": _mediaSections["size"] ?? 0, "reuseMid": null };
	}

	send(
			offerMediaObject,
			reuseMid,
			offerRtpParameters,
			answerRtpParameters,
			codecOptions,
			extmapAllowMixed
    ){
		 AnswerMediaSection mediaSection = AnswerMediaSection({
				"iceParameters"      : this._iceParameters,
				"iceCandidates"      : this._iceCandidates,
				"dtlsParameters"     : this._dtlsParameters,
				"plainRtpParameters" : this._plainRtpParameters,
				"planB"              : this._planB,
				"offerMediaObject": offerMediaObject,
				"offerRtpParameters": offerRtpParameters,
				"answerRtpParameters": answerRtpParameters,
				"codecOptions": codecOptions,
				"extmapAllowMixed": extmapAllowMixed
			});

		// Unified-Plan with closed media section replacement.
		if (reuseMid != null) {
			_replaceMediaSection(mediaSection, reuseMid: reuseMid);
		} // Unified-Plan or Plan-B with different media kind.
		else if (!_mediaSections.containsKey(mediaSection.mid)){
			_addMediaSection(mediaSection);
		}
		// Plan-B with same media kind.
		else {
			_replaceMediaSection(mediaSection);
		}
	}

	receive({mid,
			kind,
			offerRtpParameters,
			streamId,
			trackId
	}) {
		// Unified-Plan or different media kind.
		if (!_mediaSections.containsKey(mid)) {
			OfferMediaSection mediaSection = OfferMediaSection({
					"iceParameters"      : _iceParameters,
					"iceCandidates"      : _iceCandidates,
					"dtlsParameters"     : _dtlsParameters,
					"plainRtpParameters" : _plainRtpParameters,
					"planB"              : _planB,
					"mid"                : mid,
					"kind": kind,
					"offerRtpParameters": offerRtpParameters,
					"streamId": streamId,
					"trackId": trackId
				});

			_addMediaSection(mediaSection);
		}
		// Plan-B.
		else {
			OfferMediaSection mediaSection = _mediaSections["mid"];

			mediaSection.planBReceive({ "offerRtpParameters": offerRtpParameters, "streamId": streamId, "trackId": trackId });
			_replaceMediaSection(mediaSection);
		}
	}

	disableMediaSection(String mid) {
		MediaSection mediaSection = _mediaSections["mid"];

		mediaSection.disable();
	}

	closeMediaSection(String mid) {
		MediaSection mediaSection = _mediaSections["mid"];

		// NOTE: Closing the first m section is a pain since it invalidates the
		// bundled transport, so let's avoid it.
		if (mid == _firstMid) {
			disableMediaSection(mid);

			return;
		}

		mediaSection.close();

		// Regenerate BUNDLE mids.
		_regenerateBundleMids();
	}

	planBStopReceiving(data) {
    String mid = data["mid"];
    Map offerRtpParameters = data["offerRtpParameters"];
		OfferMediaSection mediaSection = _mediaSections[mid];

		mediaSection.planBStopReceiving({ "offerRtpParameters": offerRtpParameters });
		_replaceMediaSection(mediaSection);
	}

	sendSctpAssociation(Map data){
    Map offerMediaObject = data["offerMediaObject"];
		AnswerMediaSection mediaSection = AnswerMediaSection(
			{
				"iceParameters"      : _iceParameters,
				"iceCandidates"      : _iceCandidates,
				"dtlsParameters"     : _dtlsParameters,
				"sctpParameters"     : _sctpParameters,
				"plainRtpParameters" : _plainRtpParameters,
				"offerMediaObject"   : offerMediaObject
			});

		_addMediaSection(mediaSection);
	}

	receiveSctpAssociation(Map data) {
    Map oldDataChannelSpec = data["oldDataChannelSpec"];
		OfferMediaSection mediaSection = OfferMediaSection({
				"iceParameters"      : this._iceParameters,
				"iceCandidates"      : this._iceCandidates,
				"dtlsParameters"     : this._dtlsParameters,
				"sctpParameters"     : this._sctpParameters,
				"plainRtpParameters" : this._plainRtpParameters,
				"mid"                : 'datachannel',
				"kind"               : 'application',
				"oldDataChannelSpec": oldDataChannelSpec
			});

		this._addMediaSection(mediaSection);
	}

	String getSdp() {
		// Increase SDP version.
		_sdpObject["origin"]["sessionVersion"]++;

		return write(Map<String, dynamic>.from(_sdpObject), null);
	}

	_addMediaSection(MediaSection  newMediaSection) {
		if (_firstMid == null) {
			_firstMid = newMediaSection.mid.toString();
    }

		// Store it in the map.
		_mediaSections[newMediaSection.mid.toString()] = newMediaSection;

		// Update SDP object.
		_sdpObject["media"].add(newMediaSection.getObject());

		// Regenerate BUNDLE mids.
		_regenerateBundleMids();
	}

	_replaceMediaSection(MediaSection newMediaSection, {bool reuseMid}){
		// Store it in the map.
		if (reuseMid == true) {
			Map newMediaSections = Map();

			for (String mediaSectionKey in _mediaSections.keys) {
        MediaSection mediaSection  = _mediaSections[mediaSectionKey];
				if (mediaSection.mid == reuseMid) {
					newMediaSections[newMediaSection.mid] = newMediaSection;
        } else {
					newMediaSections[newMediaSection.mid] = mediaSection;
        }
			}

			// Regenerate media sections.
			_mediaSections = newMediaSections;

			// Regenerate BUNDLE mids.
			_regenerateBundleMids();
		} else {
			_mediaSections[newMediaSection.mid] = newMediaSection;
		}

		// Update SDP object.
		_sdpObject["media"] = List<Map>.from(
			_mediaSections.keys.map((String mediaSectionKey) => _mediaSections[mediaSectionKey].getObject()).toList()
    );
	}

	_regenerateBundleMids() {
    if (_dtlsParameters == null) {
      return;
    }

		_sdpObject["groups"][0]["mids"] = _mediaSections.keys
			.where((String mediaSectionKey) => !_mediaSections[mediaSectionKey].closed)
			.map((String mediaSectionKey) => _mediaSections[mediaSectionKey].mid)
			.join(' ');
	}
}
