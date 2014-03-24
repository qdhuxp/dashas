/*
 * Copyright (c) 2014 castLabs GmbH
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

package com.castlabs.dash.handlers {
import com.castlabs.dash.descriptors.Representation;
import com.castlabs.dash.descriptors.Representation;
import com.castlabs.dash.events.ManifestEvent;
import com.castlabs.dash.loaders.ManifestLoader;
import com.castlabs.dash.utils.Console;
import com.castlabs.dash.utils.Manifest;

import flash.events.TimerEvent;
import flash.utils.Timer;

public class ManifestHandler {
    private var _url:String;

    private var _live:Boolean;
    private var _duration:Number;
    private var _audioRepresentations:Vector.<Representation>;
    private var _videoRepresentations:Vector.<Representation>;

    private var _nextInternalRepresentationId:Number = 0;

    private var _updateTimer:Timer;

    public function ManifestHandler(url:String, xml:XML) {
        _url = url;
        _duration = buildDuration(xml);

        var baseUrl:String = buildBaseUrl(url);
        _audioRepresentations = buildRepresentations(baseUrl, _duration, findAudioRepresentationNodes(xml));
        _videoRepresentations = buildRepresentations(baseUrl, _duration, findVideoRepresentationNodes(xml));

        sortByBandwidth(_audioRepresentations);
        sortByBandwidth(_videoRepresentations);

        _live = buildLive(xml);
        if (_live) {
            var minimumUpdatePeriod:Number = buildMinimumUpdatePeriod(xml);

            if (minimumUpdatePeriod) {
                _updateTimer = new Timer(minimumUpdatePeriod * 1000);
                _updateTimer.addEventListener(TimerEvent.TIMER, onUpdate);
                _updateTimer.start();
            }
        }
    }

    public function get live():Boolean {
        return _live;
    }

    public function get duration():Number {
        return _duration;
    }

    public function get audioRepresentations():Vector.<Representation> {
        return _audioRepresentations;
    }

    public function get videoRepresentations():Vector.<Representation> {
        return _videoRepresentations
    }

    private function onUpdate(timerEvent:TimerEvent):void {
        var loader:ManifestLoader = new ManifestLoader(_url);
        loader.addEventListener(ManifestEvent.LOADED, onLoad);

        function onLoad(event:ManifestEvent):void {
            Console.getInstance().info("Loaded changed manifest. Updating representations...");

            for each (var representation1:Representation in _videoRepresentations) {
                representation1.update(event.xml..AdaptationSet.(@mimeType == "video/mp4")[0]);
            }

            for each (var representation2:Representation in _audioRepresentations) {
                representation2.update(event.xml..AdaptationSet.(@mimeType == "audio/mp4")[0]);
            }

            Console.getInstance().info("Updated representations");
        }

        loader.load();
    }

    private function buildMinimumUpdatePeriod(xml:XML):Number {
        if (xml.hasOwnProperty("@minimumUpdatePeriod")) {
            return Manifest.toSeconds(xml.@minimumUpdatePeriod.toString());
        }

        Console.getInstance().warn("Couldn't find minimum update period");
        return NaN;
    }

    private static function buildBaseUrl(url:String):String {
        return url.slice(0, url.lastIndexOf("/")) + "/";
    }

    private static function buildDuration(xml:XML):Number {
        if (xml.hasOwnProperty("@mediaPresentationDuration")) {
            return Manifest.toSeconds(xml.@mediaPresentationDuration.toString());
        }

        Console.getInstance().warn("Couldn't find media presentation duration");
        return NaN;
    }

    private static function buildLive(xml:XML):Boolean {
        if (xml.hasOwnProperty("@type")) {
            return xml.@type.toString() == "dynamic";
        }

        return false;
    }

    private static function findVideoRepresentationNodes(xml:XML):* {
        return findAdaptionSetNode("video/mp4", xml).Representation;
    }

    private static function findAudioRepresentationNodes(xml:XML):* {
        return findAdaptionSetNode("audio/mp4", xml).Representation;
    }

    private static function findAdaptionSetNode(mimeType:String, xml:XML):* {
        var adaptationSet:* = xml..AdaptationSet.(attribute('mimeType') == mimeType);
        if (adaptationSet.length() == 1) {
            return adaptationSet;
        } else {
            return xml..Representation.(@mimeType == mimeType)[0].parent();
        }
    }

    private function buildRepresentations(baseUrl:String, duration:Number, nodes:XMLList):Vector.<Representation> {
        var representations:Vector.<Representation> = new Vector.<Representation>();

        for each (var node:XML in nodes) {
            Console.getInstance().debug("Processing next representation...");
            var representation:Representation = new Representation(_nextInternalRepresentationId++, baseUrl, duration, node);
            Console.getInstance().info("Created representation, " + representation.toString());

            representations.push(representation);
        }

        return representations;
    }

    private static function sortByBandwidth(representations:Vector.<Representation>):void {
        representations.sort(function compare(a:Representation, b:Representation):Number {
            if (a.bandwidth < b.bandwidth) {
                return -1; // a should appear before b
            }

            if (a.bandwidth > b.bandwidth) {
                return 1; // b should appear before a
            }

            return 0; // a equals b
        });
    }

    public function toString():String {
        return "isLive='" + _live + "', duration[s]='" + _duration + "', videoRepresentationsCount='"
                + _videoRepresentations.length + "', audioRepresentationsCount='" + _audioRepresentations.length + "'";
    }
}
}
