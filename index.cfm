
<cfquery name="qCounties" datasource="plss">
	select name from global.counties
    order by name asc
</cfquery>

<cfoutput>

<!doctype html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="X-UA-Compatible" content="IE=7" />
<meta name="description" content="Interactive map of Kansas oil and gas fields and wells." />
<meta name="author" content="Mike Killion">
<meta name="copyright" content="&copy; Kansas Geological Survey">

<title>Map of #application.title#</title>

<link rel="stylesheet" type="text/css" href="style.css">

<link rel="stylesheet" href="http://js.arcgis.com/3.7/js/dojo/dijit/themes/soria/soria.css">
<link rel="stylesheet" href="http://js.arcgis.com/3.7/js/esri/css/esri.css">

<script>var dojoConfig = { parseOnLoad: true };</script>
<script src="http://js.arcgis.com/3.7/"></script>
<!--<link rel="stylesheet" href="http://js.arcgis.com/3.13/dijit/themes/soria/soria.css">
<link rel="stylesheet" href="http://js.arcgis.com/3.13/esri/css/esri.css">-->

<!--<script>var dojoConfig = { parseOnLoad: true };</script>
<script src="http://js.arcgis.com/3.13/"></script>-->

<script type="text/javascript">
    dojo.require("esri.map");
	dojo.require("esri.tasks.identify");
	dojo.require("esri.toolbars.draw");
	dojo.require("esri.tasks.find");
	dojo.require("esri.tasks.geometry");
	dojo.require("esri.tasks.query");
	dojo.require("esri.dijit.Scalebar");
	dojo.require("esri.tasks.PrintTask");
    dojo.require("esri.tasks.PrintParameters");
    dojo.require("esri.tasks.PrintTemplate");
    dojo.require("esri.SpatialReference");
    dojo.require("esri.geometry.Extent");
    dojo.require("esri.layers.agsdynamic");
    dojo.require("esri.layers.agstiled");
    dojo.require("esri.layers.ImageServiceParameters");
    dojo.require("esri.layers.ArcGISImageServiceLayer");
    dojo.require("esri.tasks.FindParameters");
    dojo.require("esri.symbols.SimpleFillSymbol");
    dojo.require("esri.symbols.SimpleLineSymbol");
    dojo.require("esri.symbols.SimpleMarkerSymbol");
    dojo.require("esri.geometry.Polygon");
    dojo.require("esri.geometry.Point");
    dojo.require("esri.graphic");
    dojo.require("esri.tasks.IdentifyParameters");
    dojo.require("esri.tasks.ProjectParameters");

	dojo.require("dijit.layout.ContentPane");
	dojo.require("dijit.layout.TabContainer");
	dojo.require("dojo.data.ItemFileReadStore");
	dojo.require("dijit.form.FilteringSelect");
	dojo.require("dijit.form.Slider");
	dojo.require("dijit.Dialog");
	dojo.require("dijit.Menu");
	dojo.require("dijit.layout.BorderContainer");

	var map, ovmap, lod;
	var resizeTimer;
	var identify, identifyParams;
	var currField = "";
	var filter, wwc5_filter;
	var label;
	var visibleWellLyr;
	var lastLocType, lastLocValue;

	var sr;
	var stateExtent;

	dojo.addOnLoad(init);

	function init(){
		esri.config.defaults.io.proxyUrl = 'http://maps.kgs.ku.edu/proxy.jsp';

		sr = new esri.SpatialReference({ wkid:3857 });
		stateExtent = new esri.geometry.Extent(-11383127, 4418038, -10523333, 4898940, sr);

		map = new esri.Map("map_div", { nav:true, logo:false });

		// Create event listeners:
		dojo.connect(map, 'onLoad', function(){
			dojo.connect(dijit.byId('map_div'), 'resize', function(){
				resizeMap();
			});

			dojo.connect(map, "onClick", executeIdTask);
			dojo.connect(map, "onExtentChange", changeOvExtent);

            // Get URL query parameters and zoom to well/field if coming from main KGS description page:
            parseURL();
		});


		// Define layers:
		baseLayer = new esri.layers.ArcGISTiledMapServiceLayer("http://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer");

		fieldsLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_fields/MapServer");

		wellsNoLabelLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_general/MapServer");
		wellsNoLabelLayer.setVisibleLayers([0]);

		wellsLeaseWellLabelLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_general/MapServer", { visible:false });
		wellsLeaseWellLabelLayer.setVisibleLayers([5]);

		wellsAPILabelLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_general/MapServer", { visible:false });
		wellsAPILabelLayer.setVisibleLayers([6]);

		wellsYearLabelLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_general/MapServer", { visible:false });
		wellsYearLabelLayer.setVisibleLayers([11]);

		wellsFormationLabelLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_general/MapServer", { visible:false });
		wellsFormationLabelLayer.setVisibleLayers([7]);

		wwc5Layer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_general/MapServer", { visible:false });
		wwc5Layer.setVisibleLayers([8]);

        plssLayer = new esri.layers.ArcGISTiledMapServiceLayer("http://services.kgs.ku.edu/arcgis8/rest/services/plss/plss/MapServer");

		wells90DaysLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_general/MapServer", { visible:false });
		wells90DaysLayer.setVisibleLayers([12]);

		lepcLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://kars.ku.edu/arcgis/rest/services/Sgpchat2013/SouthernGreatPlainsCrucialHabitatAssessmentTool2LEPCCrucialHabitat/MapServer", { visible: false} );

		earthquakesLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis1/rest/services/co2/seismic_1/MapServer", { visible:false });
		earthquakesLayer.setVisibleLayers([8]);

		var imageServiceParameters = new esri.layers.ImageServiceParameters();
        imageServiceParameters.format = "jpg";

		drgLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis7/rest/services/Elevation/USGS_Digital_Topo/MapServer", { visible:false });
		drgLayer.setVisibleLayers([11]);

		naipLayer = new esri.layers.ArcGISImageServiceLayer("http://services.kgs.ku.edu/arcgis7/rest/services/IMAGERY_STATEWIDE/FSA_NAIP_2014_Color/ImageServer", { visible:false, imageServiceParameters:imageServiceParameters });

		doqq02Layer = new esri.layers.ArcGISImageServiceLayer("http://services.kgs.ku.edu/arcgis7/rest/services/IMAGERY_STATEWIDE/Kansas_DOQQ_2002/ImageServer", { visible:false, imageServiceParameters:imageServiceParameters });

		doqq91Layer = new esri.layers.ArcGISImageServiceLayer("http://services.kgs.ku.edu/arcgis7/rest/services/IMAGERY_STATEWIDE/Kansas_DOQQ_1991/ImageServer", { visible:false, imageServiceParameters:imageServiceParameters });

		// Add layers (first layer added displays on the bottom):
		map.addLayer(baseLayer);
		map.addLayer(doqq91Layer);
		map.addLayer(doqq02Layer);
		map.addLayer(naipLayer);
		map.addLayer(drgLayer);
		map.addLayer(fieldsLayer);
		map.addLayer(lepcLayer);
		map.addLayer(earthquakesLayer);
		map.addLayer(plssLayer);
		map.addLayer(wwc5Layer);
		map.addLayer(wellsNoLabelLayer);
		map.addLayer(wellsLeaseWellLabelLayer);
		map.addLayer(wellsAPILabelLayer);
		map.addLayer(wellsFormationLabelLayer);
		map.addLayer(wellsYearLabelLayer);
		map.addLayer(wells90DaysLayer);

		visibleWellLyr = wellsNoLabelLayer;

		//esriConfig.defaults.map.sliderLabel = null;

		// Set up overview map and disable its navigation:
		ovMap = new esri.Map("ovmap_div", { slider:false, nav:false, logo:false });
		ovLayer = new esri.layers.ArcGISDynamicMapServiceLayer("http://services.kgs.ku.edu/arcgis8/rest/services/wwc5/ov_counties/MapServer");
		ovMap.addLayer(ovLayer);

		dojo.connect(ovMap, "onLoad", function() {
  			ovMap.disableMapNavigation();
		});

		map.setExtent(stateExtent, true);

		var scalebar = new esri.dijit.Scalebar({
				map: map,
			    scalebarUnit:'english'
          	});

		setScaleDependentTOC();
	}


    function parseURL() {
        var queryParams = location.search.substr(1);
        var pairs = queryParams.split("&");
        if (pairs.length > 1) {
            var extType = pairs[0].substring(11);
            var extValue = pairs[1].substring(12);

            var findTask = new esri.tasks.FindTask("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_general/MapServer");
			var findParams = new esri.tasks.FindParameters();
			findParams.returnGeometry = true;
			findParams.contains = false;

            switch (extType) {
                case "well":
                    findParams.layerIds = [0];
					findParams.searchFields = ["kid"];
                    break;
                case "field":
                    findParams.layerIds = [1];
					findParams.searchFields = ["field_kid"];
					fieldsLayer.show();
					dojo.byId('fields').checked = 'checked';
                    break;
                case "county":
                    findParams.layerIds = [2];
          			findParams.searchFields = ["county"];
                    break;
                case "plss":
                    findParams.layerIds = [3];
					findParams.searchFields = ["s_r_t"];
                    break;
            }

            lastLocType = extType;
			lastLocValue = extValue;
            findParams.searchText = extValue;
            findTask.execute(findParams,zoomToResults);
        }
    }


	function resizeMap() {
		clearTimeout(resizeTimer);
		resizeTimer = setTimeout(function(){
			map.resize();
			map.reposition();
		}, 500);
	}

	function changeOvExtent(ext) {
		padding = 12000;
		ovMapExtent = new esri.geometry.Extent(ext.xmin - padding, ext.ymin - padding, ext.xmax + padding, ext.ymax + padding, sr);

		ovMap.setExtent(ovMapExtent);

		symbol = new esri.symbol.SimpleFillSymbol(esri.symbol.SimpleFillSymbol.STYLE_SOLID, new esri.symbol.SimpleLineSymbol(esri.symbol.SimpleLineSymbol.STYLE_SOLID, new dojo.Color([255,0,0]), 2), new dojo.Color([255,0,0,0.2]));
		boxPts = new Array();
		box = new esri.geometry.Polygon(sr);

		boxNW = new esri.geometry.Point(ext.xmin, ext.ymax);
		boxSW = new esri.geometry.Point(ext.xmin, ext.ymin);
		boxSE = new esri.geometry.Point(ext.xmax, ext.ymin);
		boxNE = new esri.geometry.Point(ext.xmax, ext.ymax);

		boxPts.push(boxNW, boxSW, boxSE, boxNE, boxNW);

		box.addRing(boxPts);

		if (ovMap.graphics) {
			ovMap.graphics.clear();
			ovMap.graphics.add(new esri.Graphic(box, symbol));
		}

		// Give map time to load then toggle scale-dependent layers in table of contents:
		setTimeout(setScaleDependentTOC, 1000);

		// If filter is on, re-apply with new extent:
		if (filter != 'off') {
			filterWells(filter);
		}
	}

	function setScaleDependentTOC() {
		// On extent change, check level of detail and change styling on scale-dependent layer names:
		lod = map.getLevel();

		// PLSS:
		if (lod >= 11) {
			dojo.byId('plss_txt').innerHTML = 'Sec-Twp-Rng';
			dojo.byId('plss_txt').style.color = '##000000';
			dojo.byId('vis_msg').innerHTML = '';
		}
		else {
			dojo.byId('plss_txt').innerHTML = 'Sec-Twp-Rng*';
			dojo.byId('plss_txt').style.color = '##999999';
			dojo.byId('vis_msg').innerHTML = '* Zoom in to view layer';
		}

		// Oil & Gas Wells, WWC5:
		if (lod >= 13) {
			dojo.byId('ogwells_txt').innerHTML = 'Oil & Gas Wells';
			dojo.byId('ogwells_txt').style.color = '##000000';
			dojo.byId('vis_msg').innerHTML = '';
			dojo.byId('wwc5_txt').innerHTML = 'WWC5 Water Wells';
			dojo.byId('wwc5_txt').style.color = '##000000';
			dojo.byId('vis_msg').innerHTML = '';
		}
		else {
			dojo.byId('ogwells_txt').innerHTML = 'Oil & Gas Wells*';
			dojo.byId('ogwells_txt').style.color = '##999999';
			dojo.byId('vis_msg').innerHTML = '* Zoom in to view layer';
			dojo.byId('wwc5_txt').innerHTML = 'WWC5 Water Wells*';
			dojo.byId('wwc5_txt').style.color = '##999999';
			dojo.byId('vis_msg').innerHTML = '* Zoom in to view layer';
		}

		//dojo.byId('junk').innerHTML = lod;
	}


	function executeIdTask(evt) {
		identify = new esri.tasks.IdentifyTask("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_general/MapServer");
		// Set task parameters:
        identifyParams = new esri.tasks.IdentifyParameters();
        identifyParams.tolerance = 3;
        identifyParams.returnGeometry = true;
		identifyParams.mapExtent = map.extent;
		identifyParams.geometry = evt.mapPoint;
		identifyParams.layerIds = [12,0,8,1];
		//identifyParams.layerOption = "LAYER_OPTION_TOP"

        //Execute task:
		identify.execute(identifyParams, function(fset) {
			addToMap(fset,evt);
		});
	}


	function sortAPI(a, b) {
        var numA = a.feature.attributes["api_number"];
        var numB = b.feature.attributes["api_number"];
        if (numA < numB) { return -1 }
        if (numA > numB) { return 1 }
        return 0;
    }


	function addToMap(results,evt) {
		featureset = results;

		if (featureset.length > 1) {
			var content = "";
			var selectionType = "";
		}
		else {
			var title = results.length + " features were selected:";
			var content = "Please zoom in further to select a well.";
			var isSelection = false;
		}

		if (results.length == 1) {
			if (featureset[0].layerId == 0 || featureset[0].layerId == 8 || featureset[0].layerId == 12) {
				showPoint(featureset[0].feature, featureset[0].layerId);
			}
			else {
				//fieldsLayer.show();
				//dojo.byId('fields').checked = 'checked';
				if (dojo.byId('fields').checked) {
					showPoly(featureset[0].feature);
				}

				//showPoly(featureset[0].feature);
			}
		}
		else {
			results.sort(sortAPI);

			for (var i = 0, il = results.length; i < il; i++) {
				var graphic = results[i].feature;

			  	switch (graphic.geometry.type) {
					case "point":
				  		var symbol = new esri.symbol.SimpleMarkerSymbol(esri.symbol.SimpleMarkerSymbol.STYLE_CIRCLE, 10, new esri.symbol.SimpleLineSymbol(esri.symbol.SimpleLineSymbol.STYLE_SOLID, new dojo.Color([255,255,0]), 1), new dojo.Color([255,255,0,0.25]));
				 		break;
					case "polyline":
				  		var symbol = new esri.symbol.SimpleLineSymbol(esri.symbol.SimpleLineSymbol.STYLE_DASH, new dojo.Color([0,255,0]), 1);
				  		break;
					case "polygon":
				  		var symbol = new esri.symbol.SimpleFillSymbol(esri.symbol.SimpleFillSymbol.STYLE_NULL, new esri.symbol.SimpleLineSymbol(esri.symbol.SimpleLineSymbol.STYLE_SOLID, new dojo.Color([255,255,0]), 3), new dojo.Color([0,255,0,0.25]));
				 		break;
					case "multipoint":
				  		var symbol = new esri.symbol.SimpleMarkerSymbol(esri.symbol.SimpleMarkerSymbol.STYLE_DIAMOND, 20, new esri.symbol.SimpleLineSymbol(esri.symbol.SimpleLineSymbol.STYLE_SOLID, new dojo.Color([0,0,0]), 1), new dojo.Color([0,255,0,0.5]));
				  		break;
			  	}

			  	graphic.setSymbol(symbol);

				switch (featureset[0].layerId) {
					case 12:
						selectionType = "well";
						var title = results.length + " oil or gas wells were selected:";
						content += "<tr><td width='*'>" + results[i].feature.attributes["LEASE_NAME"] + " " + results[i].feature.attributes["WELL_NAME"] + "</td><td width='15%'>" + results[i].feature.attributes["API_NUMBER"] + "</td><td width='10%'>" + results[i].feature.attributes["STATUS"] + "</td><td width='10%' align='center'><A style='text-decoration:underline;color:blue;cursor:pointer' onclick='showPoint(featureset[" + i + "].feature,12);'>display</A></td></tr>";
						break;
					case 0:
						selectionType = "well";
						var title = results.length + " oil or gas wells were selected:";
						content += "<tr><td width='*'>" + results[i].feature.attributes["LEASE_NAME"] + " " + results[i].feature.attributes["WELL_NAME"] + "</td><td width='15%'>" + results[i].feature.attributes["API_NUMBER"] + "</td><td width='10%'>" + results[i].feature.attributes["STATUS"] + "</td><td width='10%' align='center'><A style='text-decoration:underline;color:blue;cursor:pointer' onclick='showPoint(featureset[" + i + "].feature,0);'>display</A></td></tr>";
						break;
					case 1:
						selectionType = "field";
						var title = results.length + " fields were selected:";
						content += "<tr><td>" + results[i].feature.attributes["FIELD_NAME"] + "</td><td><A style='text-decoration:underline;color:blue;cursor:pointer;' onclick='showPoly(featureset[" + i + "].feature,1);'>display</A></td></tr>";
						break;
					case 8:
						selectionType = "wwc5";
						var title = results.length + " water wells were selected:";

						var status = "";
						if (results[i].feature.attributes["TYPE_OF_ACTION_CODE"] == 1) {
							status = "Constructed";
						}

						if (results[i].feature.attributes["TYPE_OF_ACTION_CODE"] == 2) {
							status = "Reconstructed";
						}

						if (results[i].feature.attributes["TYPE_OF_ACTION_CODE"] == 3) {
							status = "Plugged";
						}

						var useCodeAtt = results[i].feature.attributes["WATER_USE_CODE"];
						switch (useCodeAtt) {
							case '1':
								useCode = "Domestic";
								break;
							case '2':
								useCode = "Irrigation";
								break;
							case '4':
								useCode = "Industrial";
								break;
							case '5':
								useCode = "Public Water Supply";
								break;
							case '6':
								useCode = "Oil Field Water Supply";
								break;
							case '7':
								useCode = "Lawn and Garden - domestic only";
								break;
							case '8':
								useCode = "Air Conditioning";
								break;
							case '9':
								useCode = "Dewatering";
								break;
							case '10':
								useCode = "Monitoring well/observation/piezometer";
								break;
							case '11':
								useCode = "Injection well/air sparge (AS)/shallow";
								break;
							case '12':
								useCode = "Other";
								break;
							case '107':
								useCode = "Test hole/well";
								break;
							case '116':
								useCode = "Feedlot/Livestock/Windmill";
								break;
							case '122':
								useCode = "Recovery/Soil Vapor Extraction/Soil Vent";
								break;
							case '183':
								useCode = "(unstated)/abandoned";
								break;
							case '189':
								useCode = "Road Construction";
								break;
							case '237':
								useCode = "Pond/Swimming Pool/Recreation";
								break;
							case '240':
								useCode = "Cathodic Protection Borehole";
								break;
							case '242':
								useCode = "Recharge Well";
								break;
							case '245':
								useCode = "Heat Pump (Closed Loop/Disposal), Geothermal";
								break;
							case '260':
								useCode = "Domestic, changed from Irrigation";
								break;
							case '270':
								useCode = "Domestic, changed from Oil Field Water Supply";
								break;
							default:
								useCode = "";
						}

						content += "<tr><td width='*'>" + results[i].feature.attributes["OWNER_NAME"] + "</td><td width='25%'>" + useCode + "</td><td width='15%'>" + status + "</td><td width='15%' align='center'><A style='text-decoration:underline;color:blue;cursor:pointer' onclick='showPoint(featureset[" + i + "].feature,8);'>display</A><br/>";
						break;
				}

			}

			if (selectionType == "well") {
				content = "<table border='1' cellpadding='3'><tr><th>LEASE/WELL</th><th>API NUMBER</th><th>WELL TYPE</th><th>INFO</th></tr>" + content + "</table><p><input type='button' value='Close' onClick='map.infoWindow.hide();' />";
			}

			if (selectionType == "field") {
				content = "<table border='1' cellpadding='3'<tr><th>FIELD NAME</th><th>INFO</th></tr>" + content + "</table><p><input type='button' value='Close' onClick='map.infoWindow.hide();' />";
			}

			if (selectionType == "wwc5") {
				content = "<table border='1' cellpadding='3'><tr><th>OWNER</th><th>WELL USE</th><th>STATUS</th><th>INFO</th></tr>" + content + "</table><p><input type='button' value='Close' onClick='map.infoWindow.hide();' />";
			}

			map.infoWindow.resize(450, 300);
			map.infoWindow.setTitle(title);
			map.infoWindow.setContent(content);
			map.infoWindow.show(evt.screenPoint,map.getInfoWindowAnchor(evt.screenPoint));
		}
	}


	function showPoint(feature, lyrId) {
		map.graphics.clear();

		// Highlight selected feature:
		if (lyrId == 10)
		{
			var ptSymbol = new esri.symbol.SimpleMarkerSymbol();
			ptSymbol.setStyle(esri.symbol.SimpleMarkerSymbol.STYLE_X);
			ptSymbol.setOutline(new esri.symbol.SimpleLineSymbol(esri.symbol.SimpleLineSymbol.STYLE_SOLID, new dojo.Color([255,255,0]), 3));
			ptSymbol.size = 20;
			feature.setSymbol(ptSymbol);
		}
		else
		{
			var ptSymbol = new esri.symbol.SimpleMarkerSymbol(esri.symbol.SimpleMarkerSymbol.STYLE_CIRCLE, 20, new esri.symbol.SimpleLineSymbol(esri.symbol.SimpleLineSymbol.STYLE_SOLID, new dojo.Color([255,255,0],1), 4), new dojo.Color([255,255,0,0.5]));

			feature.setSymbol(ptSymbol);
		}

		map.graphics.add(feature);

		if (lyrId == 0) {
			// oil or gas well.
			var idURL = "retrieve_info.cfm?get=well&kid=" + feature.attributes.KID + "&api=" + feature.attributes.api_number;
		}
		else if (lyrId == 12) {
			// 90 day well, attribute is uppercase in this layer, lower case in the main og well layer.
			var idURL = "retrieve_info.cfm?get=well&kid=" + feature.attributes.KID + "&api=" + feature.attributes.API_NUMBER;
		}
		else if (lyrId == 8) {
			// wwc5 well.
			var idURL = "retrieve_info.cfm?get=wwc5&seq=" + feature.attributes.INPUT_SEQ_NUMBER;
		}

		if (lyrId != 10)
		{
			// Make an ajax request to retrieve well info (content is formatted in retrieve_info.cfm):
			dojo.xhrGet( {
				url: idURL,
				handleAs: "text",
				load: function(response, ioArgs) {
					dojo.byId('infoTab').innerHTML = response;
					return response;
				},
				/*error: function(err) {
					alert(err);
				},*/
				timeout: 180000
			});

			// Make Info tab active:
			tabContainer = dijit.byId('mainTabContainer');
			tabContainer.selectChild('infoTab');
		}
	}


	function showPoly(feature) {
        map.graphics.clear();
		map.infoWindow.hide();

		// Highlight selected feature:
        var symbol = new esri.symbol.SimpleFillSymbol(esri.symbol.SimpleFillSymbol.STYLE_NULL, new esri.symbol.SimpleLineSymbol(esri.symbol.SimpleLineSymbol.STYLE_SOLID, new dojo.Color([255,255,0]), 4), new dojo.Color([255,0,0,0.25]))
		feature.setSymbol(symbol);

		map.graphics.add(feature);

		var kid = feature.attributes.FIELD_KID;

		// Make an ajax request to retrieve field info (content is formatted in retrieve_info.cfm):
		dojo.xhrGet( {
			url: "retrieve_info.cfm?get=field&kid=" + kid,
			handleAs: "text",
			load: function(response, ioArgs) {
				dojo.byId('infoTab').innerHTML = response;
				return response;
			},
			/*error: function(err) {
				alert(err);
			},*/
			timeout: 180000
		});

		// Make Info tab active:
		tabContainer = dijit.byId('mainTabContainer');
		tabContainer.selectChild('infoTab');

		currField = kid;

		if (filter == "selected_field") {
			filterWells('selected_field');
		}
	}


	function createDownloadFile() {
		// Reproject extent to NAD27, then request well records inside new extent:

		var outSR = new esri.SpatialReference({ wkid: 4267});

		var gsvc = new esri.tasks.GeometryService("http://services.kgs.ku.edu/arcgis8/rest/services/Utilities/Geometry/GeometryServer");
		gsvc.project([ map.extent ], outSR, function(features) {
			//var outCoords = features[0].geometry;
			var xMin = features[0].xmin;
			var xMax = features[0].xmax;
			var yMin = features[0].ymin;
			var yMax = features[0].ymax;

			dojo.byId('loading_div').style.top = "-" + (map.height / 2 + 50) + "px";
			dojo.byId('loading_div').style.left = map.width / 2 + "px";
			dojo.byId('loading_div').style.display = "block";

			dojo.xhrGet( {
				url: 'download_file.cfm?xmin=' + xMin + '&xmax=' + xMax + '&ymin=' + yMin + '&ymax=' + yMax + '&filter=' + filter + '&field=' + currField,
				handleAs: "text",
				load: function(response) {
					dojo.byId('loading_div').style.display = "none";
					dijit.byId('download_results').show();
					dojo.byId('download_msg').innerHTML = response;
				},
				error: function(err) {
					alert(err);
				},
				timeout: 600000
			});
		});
	}


	function checkDownload() {
		var lod = map.getLevel();

		if (lod >= 13) { // Prevent user from downloading all wells.
			dijit.byId('download').show();
		}
		else {
			// Show warning dialog box:
			dojo.byId('warning_msg').innerHTML = "Please zoom in to limit the number of wells.";
			dijit.byId('warning_box').show();
		}
	}


	function zoomToResults(results) {
		if (results.length == 0) {
			// Show warning dialog box:
			dojo.byId('warning_msg').innerHTML = "This search did not return any features.<br>Please check your entries and try again.";
			dijit.byId('warning_box').show();
		}

		var feature = results[0].feature;

		switch (feature.geometry.type) {
			case "point":
				// Set extent around well (slightly offset so well isn't behind field label), and draw a highlight circle around it:
				var x = feature.geometry.x;
				var y = feature.geometry.y;

				var point = new esri.geometry.Point([x,y],sr);
				map.centerAndZoom(point,16);

				var lyrId = results[0].layerId;
				showPoint(feature,lyrId);
				break;
			case "polygon":
				var ext = feature.geometry.getExtent();

				// Pad extent so entire feature is visible when zoomed to:
				var padding = 1000;
				ext.xmax += padding;
				ext.xmin -= padding;
				ext.ymax += padding;
				ext.ymin -= padding;

				map.setExtent(ext);

				var lyrId = results[0].layerId;
				showPoly(feature,lyrId);
				break;
		}
	}


	function changeMap(layer, chkObj) {
		if (layer == "wells") {
			switch (visibleWellLyr) {
				case wellsNoLabelLayer:
					layer = wellsNoLabelLayer;
					break;

				case wellsLeaseWellLabelLayer:
					layer = wellsLeaseWellLabelLayer;
					break;

				case wellsAPILabelLayer:
					layer = wellsAPILabelLayer;
					break;

				case wellsFormationLabelLayer:
					layer = wellsFormationLabelLayer;
					break;
			}
		}

		if (chkObj.checked) {
			layer.show();
		}
		else {
			layer.hide();
		}
	}


	function changeOpacity(layers, opa) {
		trans = (10 - opa)/10;
		layers.setOpacity(trans);
	}


	function quickZoom(type, value, button) {
		console.log(button);
		findTask = new esri.tasks.FindTask("http://services.kgs.ku.edu/arcgis8/rest/services/oilgas/oilgas_general/MapServer");

		findParams = new esri.tasks.FindParameters();
		findParams.returnGeometry = true;
		findParams.contains = false;

		switch (type) {
			case 'county':
				findParams.layerIds = [2];
				findParams.searchFields = ["county"];
				findParams.searchText = value;
				break;

			case 'field':
				findParams.layerIds = [1];

				if (button == 'return') {
					findParams.searchFields = ["field_kid"];
					findParams.searchText = value;
				}
				else {
					findParams.searchFields = ["field_name"];
					findParams.searchText = value;
				}

				fieldsLayer.show();
				dojo.byId('fields').checked = 'checked';
				break;

			case 'well':
				findParams.layerIds = [0];

				if (button == 'return') {
					findParams.searchFields = ["kid"];
					findParams.searchText = value;
				}
				else {
					var apiText = dojo.byId('api_state').value + "-" + dojo.byId('api_county').value + "-" + dojo.byId('api_number').value;

					if (dojo.byId('api_extension').value != "" && dojo.byId('api_extension').value != "0000") {
						apiText = apiText + "-" + dojo.byId('api_extension').value;
					}

					findParams.searchFields = ["api_number"];
					findParams.searchText = apiText;
				}
				break;

			case 'plss':
				var plssText;

				if (button == 'return') {
					findParams.layerIds = [3];
					findParams.searchFields = ["s_r_t"];
					findParams.searchText = value;
				}
				else {
					// Format search string - if section is not specified search for township/range only (in different layer):
					if (dojo.byId('rng_dir_e').checked == true) {
						var rngDir = 'E';
					}
					else {
						var rngDir = 'W';
					}

					if (dojo.byId('sec').value != "") {
						plssText = 'S' + dojo.byId('sec').value + '-T' + dojo.byId('twn').value + 'S-R' + dojo.byId('rng').value + rngDir;
						findParams.layerIds = [3];
						findParams.searchFields = ["s_r_t"];
					}
					else {
						plssText = 'T' + dojo.byId('twn').value + 'S-R' + dojo.byId('rng').value + rngDir;
						findParams.layerIds = [4];
						findParams.searchFields = ["t_r"];
					}

					findParams.searchText = plssText;
				}
				break;
			case 'town':
				findParams.layerIds = [10];
				findParams.searchFields = ["feature_na"];
				findParams.searchText = value;
				break;
		}

		// Hide dialog box:
		dijit.byId('quickzoom').hide();

		// Execute task and zoom to feature:
		findTask.execute(findParams, function(fset) {
			zoomToResults(fset);
		});
	}


	function fullExtent() {
		map.setExtent(stateExtent);
	}


	function jumpFocus(nextField,chars,currField) {
		if (dojo.byId(currField).value.length == chars) {
			dojo.byId(nextField).focus();
		}
	}


	function filterWells(method) {
		var layerDef = [];
		var mExt = map.extent;

		if (label == 'leasewell') {
			lyrID = 5;
		}
		else if (label == 'api') {
			lyrID = 6;
		}
		else if (label == 'formation') {
			lyrID = 7;
		}
		else if (label == 'year') {
			lyrID = 11;
		}
		else {
			lyrID = 0;
		}

		switch (method) {
			case 'off':
				layerDef[lyrID] = "";
				visibleWellLyr.setLayerDefinitions(layerDef);
				dojo.byId('filter_on').style.display = "none";
				filter = "off";
				break;

			case 'selected_field':
				if (filter != "selected_field") {
					filter = "selected_field";
				}

				if (currField == "") {
					// Show warning dialog box:
					dojo.byId('warning_msg').innerHTML = "Please select a field before using this tool.";
					dijit.byId('warning_box').show();
				}
				else {
					layerDef[lyrID] = "FIELD_KID = " + currField;
					visibleWellLyr.setLayerDefinitions(layerDef);
					dojo.byId('filter_on').style.display = "block";
					filter = "selected_field";
					dojo.byId('filter_msg').innerHTML = "Only showing wells assigned to the selected field ";
				}
				break;

			case 'scanned':
				map.graphics.clear();
				layerDef[lyrID] = "kid in (select well_header_kid from elog.scan_urls)";
				visibleWellLyr.setLayerDefinitions(layerDef);
				dojo.byId('filter_on').style.display = "block";
				filter = "scanned";
				dojo.byId('filter_msg').innerHTML = "Only showing wells with scanned logs ";
				break;

			case 'paper':
				map.graphics.clear();
				layerDef[lyrID] = "kid in (select well_header_kid from elog.log_headers)";
				visibleWellLyr.setLayerDefinitions(layerDef);
				dojo.byId('filter_on').style.display = "block";
				filter = "paper";
				dojo.byId('filter_msg').innerHTML = "Only showing wells with paper logs ";
				break;

			case 'cuttings':
				map.graphics.clear();
				layerDef[lyrID] = "kid in (select well_header_kid from cuttings.boxes)";
				visibleWellLyr.setLayerDefinitions(layerDef);
				dojo.byId('filter_on').style.display = "block";
				filter = "cuttings";
				dojo.byId('filter_msg').innerHTML = "Only showing wells with rotary cutting samples ";
				break;

			case 'cores':
				map.graphics.clear();
				layerDef[lyrID] = "kid in (select well_header_kid from core.core_headers)";
				visibleWellLyr.setLayerDefinitions(layerDef);
				dojo.byId('filter_on').style.display = "block";
				filter = "cores";
				dojo.byId('filter_msg').innerHTML = "Only showing wells with core samples ";
				break;

			case 'horiz':
				map.graphics.clear();
				layerDef[lyrID] = "substr(api_workovers, 1, 2) <> '00'";
				visibleWellLyr.setLayerDefinitions(layerDef);
				dojo.byId('filter_on').style.display = "block";
				filter = "horiz";
				dojo.byId('filter_msg').innerHTML = "Only showing horizontal wells ";
				break;

			case 'active_well':
				map.graphics.clear();
				layerDef[lyrID] = "status not like '%&A'";
				visibleWellLyr.setLayerDefinitions(layerDef);
				dojo.byId('filter_on').style.display = "block";
				filter = "active_well";
				dojo.byId('filter_msg').innerHTML = "Only showing active wells ";
				break;
			case 'las':
				map.graphics.clear();
				layerDef[lyrID] = "kid in (select well_header_kid from las.well_headers where proprietary = 0)";
				visibleWellLyr.setLayerDefinitions(layerDef);
				dojo.byId('filter_on').style.display = "block";
				filter = "las";
				dojo.byId('filter_msg').innerHTML = "Only showing wells with LAS files ";
				break;
			case 'show_monitoring':
				map.graphics.clear();
				layerDef[8] = "";
				wwc5Layer.setLayerDefinitions(layerDef);
				dojo.byId('wwc5_filter_on').style.display = "none";
				wwc5_filter = "off";
				break;
			case 'remove_monitoring':
				map.graphics.clear();
				layerDef[8] = "water_use_code not in (8,10,11,122,240,242,245)";
				wwc5Layer.setLayerDefinitions(layerDef);
				dojo.byId('wwc5_filter_on').style.display = "block";
				wwc5_filter = "remove_monitoring";
				dojo.byId('wwc5_filter_msg').innerHTML = "Water Wells: Monitoring/Engineering Wells Excluded";
				break;
			case 'wwc5_off':
				layerDef[8] = "";
				wwc5Layer.setLayerDefinitions(layerDef);
				dojo.byId('wwc5_filter_on').style.display = "none";
				wwc5_filter = "off";
				break;
		}
	}


	function setVisibleWellLayer(labelLyr) {
		visibleWellLyr.hide();

		switch (labelLyr) {
			case 'none':
				visibleWellLyr = wellsNoLabelLayer;
				label = 'none';
				break;

			case 'leasewell':
				visibleWellLyr = wellsLeaseWellLabelLayer;
				label = 'leasewell';
				break;

			case 'api':
				visibleWellLyr = wellsAPILabelLayer;
				label = 'api';
				break;

			case 'formation':
				visibleWellLyr = wellsFormationLabelLayer;
				label = 'formation';
				break;
			case 'year':
				visibleWellLyr = wellsYearLabelLayer;
				label = 'year';
				break;
		}

		filterWells(filter);
		visibleWellLyr.show();
	}

	function printPDF() {
		var printUrl = 'http://services.kgs.ku.edu/arcgis5/rest/services/Utilities/PrintingTools/GPServer/Export%20Web%20Map%20Task';
		var printTask = new esri.tasks.PrintTask(printUrl);
        var printParams = new esri.tasks.PrintParameters();
        var template = new esri.tasks.PrintTemplate();
		var w, h;
		var printOutSr = new esri.SpatialReference({ wkid:26914 });

		/*if (dojo.byId('plss').checked) {
			plssLayer.hide();
			map.addLayer(plssDynLayer);
			plssDynLayer.show();
		}*/

		title = dojo.byId("pdftitle2").value;

		if (dojo.byId('portrait2').checked) {
			var layout = "Letter ANSI A Portrait";
		} else {
			var layout = "Letter ANSI A Landscape";
		}

		dijit.byId('printdialog2').hide();
		dojo.byId('printing_div').style.display = "block";

		if (dojo.byId('maponly').checked) {
			layout = 'MAP_ONLY';
			format = 'JPG';

			if (dojo.byId('portrait2').checked) {
				w = 600;
				h = 960;
			} else {
				w = 960;
				h = 600;
			}

			template.exportOptions = {
  				width: w,
  				height: h,
  				dpi: 96
			};
		} else {
			format = 'PDF';
		}

        template.layout = layout;
		template.format = format;
        template.preserveScale = true;
		template.showAttribution = false;
		template.layoutOptions = {
			scalebarUnit: "Miles",
			titleText: title,
			authorText: "Kansas Geological Survey",
			copyrightText: "http://maps.kgs.ku.edu/oilgas",
			legendLayers: []
		};

		printParams.map = map;
		printParams.outSpatialReference = printOutSr;
        printParams.template = template;

        printTask.execute(printParams, printResult, printError);
	}


	function printResult(result){
		dojo.byId('printing_div').style.display = "none";
		window.open(result.url);
    }

    function printError(result){
        console.log(result);
    }

    function filterQuakes(year, mag) {
        var nextYear = parseInt(year) + 1;
        var def = [];

        if (year !== "all") {
            if (mag !== "all") {
                def[8] = "the_date >= to_date('" + year + "-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS') and the_date < to_date('" + nextYear + "-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS') and net in ('us', ' ', 'US') and mag >=" + mag;
            } else {
                def[8] = "the_date >= to_date('" + year + "-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS') and the_date < to_date('" + nextYear + "-01-01 00:00:00','YYYY-MM-DD HH24:MI:SS') and mag >= 2 and net in ('us', ' ', 'US')";
            }
        } else {
            if (mag !== "all") {
                def[8] = " mag >=" + mag;
            } else {
                def[8] = "";
            }
        }

        earthquakesLayer.setLayerDefinitions(def);
    }

    function filterQuakesRecent() {
    	var def = [];
    	def[8] = "state = 'KS' and mag >= 2 and net in ('us', ' ', 'US') and the_date = (select max(the_date) from earthquakes where state = 'KS' and mag >= 2 and net in ('us', ' ', 'US'))";
    	earthquakesLayer.setLayerDefinitions(def);
    }

    function filterQuakesDays(days) {
        var def = [];

        if (days !== "all") {
            def[8] = "sysdate - the_date <= " + days + " and mag >= 2 and net in ('us', ' ', 'US')";
        } else {
            def[8] = "";
        }
        earthquakesLayer.setLayerDefinitions(def);
    }

    function clearQuakeFilter() {
        var def = [];
        def = "";
        earthquakesLayer.setLayerDefinitions(def);
        days.options[0].selected="selected";
        mag.options[0].selected="selected";
        year.options[0].selected="selected";
    }


    function zoomToLatLong(lat,lon,datum) {
		var gsvc = new esri.tasks.GeometryService("http://services.kgs.ku.edu/arcgis8/rest/services/Utilities/Geometry/GeometryServer");
		var params = new esri.tasks.ProjectParameters();
		var wgs84Sr = new esri.SpatialReference( { wkid: 4326 } );

		if (lon > 0) {
			lon = 0 - lon;
		}

		switch (datum) {
			case "nad27":
				var srId = 4267;
				break;
			case "nad83":
				var srId = 4269;
				break;
			case "wgs84":
				var srId = 4326;
				break;
		}

		var p = new esri.geometry.Point(lon, lat, new esri.SpatialReference( { wkid: srId } ) );
		params.geometries = [p];
		params.outSR = wgs84Sr;

		gsvc.project(params, function(features) {
			var pt84 = new esri.geometry.Point(features[0].x, features[0].y, wgs84Sr);

			var wmPt = esri.geometry.geographicToWebMercator(pt84);

			var ptSymbol = new esri.symbol.SimpleMarkerSymbol();
			ptSymbol.setStyle(esri.symbol.SimpleMarkerSymbol.STYLE_X);
			ptSymbol.setOutline(new esri.symbol.SimpleLineSymbol(esri.symbol.SimpleLineSymbol.STYLE_SOLID, new dojo.Color([255,0,0]), 3));
			ptSymbol.size = 20;

			map.graphics.clear();
			var graphic = new esri.Graphic(wmPt,ptSymbol);
			map.graphics.add(graphic);

			map.centerAndZoom(wmPt, 17);
		} );

		dijit.byId('quickzoom').hide();
	}


    function submitComments(l, t, c, o) {
        dojo.xhrGet( {
            url: "suggestions.cfm?layers="+l+"&tools="+t+"&comments="+c+"&occ="+o
        });

        updateCommentCount();

        dijit.byId('suggestionBox').hide();
    }

    function updateCommentCount() {
        dojo.xhrGet( {
            url: "commentcount.cfm",
            handleAs: "text",
            load: function(response, ioArgs) {
                dojo.byId('commentcount').innerHTML = response;
                return response;
            }
        });
    }

</script>
</head>

<body class="soria">
<!-- Topmost container: -->
<div id="mainWindow" dojotype="dijit.layout.BorderContainer" design="headline" gutters="false" style="width:100%; height:100%;">

	<!--Header: -->
	<div id="header" dojotype="dijit.layout.ContentPane" region="top" >
		<div style="padding:5px; font:normal normal bold 18px Arial; color:##FFFF66;">
        	#application.title#
        	<span id="kgs" style="position:fixed; right:55px; padding-top:2px;"><a style="font-weight:normal; font-size:12px; color:yellow; text-decoration:none;" href="http://www.kgs.ku.edu">Kansas Geological Survey</a></span>
        </div>
        <div id="toolbar">
        	<span class="tool_link" onClick="fullExtent();">Statewide View</span> &nbsp;|&nbsp;
            <span class="tool_link" onClick="dijit.byId('quickzoom').show();">Zoom to Location</span>&nbsp;|&nbsp;
            <span class="tool_link" id="filter">Filter Wells</span>&nbsp;|&nbsp;
            <span class="tool_link" id="label">Label Wells</span>&nbsp;|&nbsp;
            <span class="tool_link" onClick="checkDownload();">Download Wells</span>&nbsp;|&nbsp;
           	<span class="tool_link" onclick="dijit.byId('printdialog2').show();">Print to PDF</span>&nbsp;|&nbsp;
            <span class="tool_link" onClick="map.graphics.clear();">Clear Highlight</span>&nbsp;|&nbsp;
            <a class="tool_link" href="help.cfm" target="_blank">Help</a>
       	</div>
	</div>

	<!-- Center container: -->
	<div id="map_div" dojotype="dijit.layout.ContentPane" region="center" style="background-color:white;"></div>

	<!-- Right container: -->
	<div dojotype="dijit.layout.ContentPane" region="right" id="sidebar" style="width:260px;border-left: medium solid ##0013AA;">
		<div id="mainTabContainer" class="mainTab" dojoType="dijit.layout.TabContainer" >
            <div id="layersTab" dojoType="dijit.layout.ContentPane" title="Layers">
                <table>
                <tr><td>Layer</td><td>Transparency</td></tr>
                <tr>
                    <td><input type="checkbox" id="wells" onClick="changeMap('wells',this);" checked><span id="ogwells_txt"></span></td>
                    <td></td>
                </tr>
                <tr>
                    <td colspan="2" nowrap><input type="checkbox" id="wells39days" onClick="changeMap(wells90DaysLayer,this);">Wells Reported Spudded in Last 90 Days</td>
                    <td></td>
                </tr>
                <tr>
                    <td nowrap="nowrap"><input type="checkbox" id="wwc5" onClick="changeMap(wwc5Layer,this);"><span id="wwc5_txt"></span></td>
                    <td></td>
                </tr>
                <tr>
                    <td><input type="checkbox" id="plss" onClick="changeMap(plssLayer,this);" checked><span id="plss_txt"></span></td>
                    <td></td>
                </tr>
                <tr>
                    <td colspan="2"><input type="checkbox" id="earthquakes" onClick="changeMap(earthquakesLayer,this,'earthquakes','Earthquakes');">Earthquakes 2.0+&nbsp;&nbsp;&nbsp;<span style="text-decoration:underline;cursor:pointer;font-size:12px;" onclick="dijit.byId('quakefilter').show();">Filter</span>&nbsp;&nbsp;&nbsp;<img src="images/question.png" height="15" width="15" align="bottom" style="cursor:pointer" onclick="dijit.byId('quakenotes').show();" /></td>
                </tr>

                <tr>
                    <td nowrap><input type="checkbox" id="eor10" onClick="changeMap(lepcLayer,this);">LEPC Crucial Habitat&nbsp;<img src="images/question.png" height="15" width="15" style="cursor:pointer" onclick="dijit.byId('lepcnotes').show();" /></td>
                    <td>
                        <div id="horizontalSlider_lepc" dojoType="dijit.form.HorizontalSlider" value="0" minimum="0" maximum="10" discreteValues="11"
                            intermediateChanges="true" style="width:75px"
                            onChange="dojo.byId('horizontalSlider_lepc').value = arguments[0];changeOpacity(lepcLayer,dojo.byId('horizontalSlider_lepc').value);">
                        </div>
                    </td>
                </tr>

                <tr>
                    <td><input type="checkbox" id="fields" onClick="changeMap(fieldsLayer,this);" checked>Oil & Gas Fields</td>
                    <td>
                        <div id="horizontalSlider_fields" dojoType="dijit.form.HorizontalSlider" value="0" minimum="0" maximum="10" discreteValues="11"
                            intermediateChanges="true" style="width:75px"
                            onChange="dojo.byId('horizontalSlider_fields').value = arguments[0];changeOpacity(fieldsLayer,dojo.byId('horizontalSlider_fields').value);">
                        </div>
                    </td>
                </tr>

                <tr>
                    <td><input type="checkbox" id="drg" onClick="changeMap(drgLayer,this);">Topographic Map</td>
                    <td>
                        <div id="horizontalSlider_drg" dojoType="dijit.form.HorizontalSlider" value="0" minimum="0" maximum="10" discreteValues="11"
                            intermediateChanges="true" style="width:75px"
                            onChange="dojo.byId('horizontalSlider_drg').value = arguments[0];changeOpacity(drgLayer,dojo.byId('horizontalSlider_drg').value);">
                        </div>
                    </td>
                </tr>
                <tr>
                    <td><input type="checkbox" id="naip" onClick="changeMap(naipLayer,this);">2014 Aerials</td>
                    <td>
                        <div id="horizontalSlider_naip" dojoType="dijit.form.HorizontalSlider" value="0" minimum="0" maximum="10" discreteValues="11"
                            intermediateChanges="true" style="width:75px"
                            onChange="dojo.byId('horizontalSlider_naip').value = arguments[0];changeOpacity(naipLayer,dojo.byId('horizontalSlider_naip').value);">
                        </div>
                    </td>
                </tr>
                <tr>
                    <td><input type="checkbox" id="doqq02" onClick="changeMap(doqq02Layer,this);">2002 B&W Aerials</td>
                    <td>
                        <div id="horizontalSlider_doqq02" dojoType="dijit.form.HorizontalSlider" value="0" minimum="0" maximum="10" discreteValues="11"
                            intermediateChanges="true" style="width:75px"
                            onChange="dojo.byId('horizontalSlider_doqq02').value = arguments[0];changeOpacity(doqq02Layer,dojo.byId('horizontalSlider_doqq02').value);">
                        </div>
                    </td>
                </tr>

                <tr>
                    <td><input type="checkbox" id="doqq91" onClick="changeMap(doqq91Layer,this);">1991 B&W Aerials</td>
                    <td>
                        <div id="horizontalSlider_doqq91" dojoType="dijit.form.HorizontalSlider" value="0" minimum="0" maximum="10" discreteValues="11"
                            intermediateChanges="true" style="width:75px"
                            onChange="dojo.byId('horizontalSlider_doqq91').value = arguments[0];changeOpacity(doqq91Layer,dojo.byId('horizontalSlider_doqq91').value);">
                        </div>
                    </td>
                </tr>

                <tr>
                    <td><input type="checkbox" id="base" onClick="changeMap(baseLayer,this);" checked>Base map</td>
                    <td>
                        <div id="horizontalSlider_base" dojoType="dijit.form.HorizontalSlider" value="0" minimum="0" maximum="10" discreteValues="11"
                            intermediateChanges="true" style="width:75px"
                            onChange="dojo.byId('horizontalSlider_base').value = arguments[0];changeOpacity(baseLayer,dojo.byId('horizontalSlider_base').value);">
                        </div>
                    </td>
                </tr>
                <tr><td class="note" id="vis_msg" colspan="2">* Layer not visible at all scales</td></tr>
                </table>

                <div id="ovmap_div"></div>
            </div>

            <div class="tab" id="infoTab" dojoType="dijit.layout.ContentPane" title="Info">Click on a well or field to display information.</div>

            <div class="tab" id="legendTab" dojoType="dijit.layout.ContentPane" title="Legend">
    			<b>Wells</b>
                <br>
                <img src="images/well_sym.jpg" />
                <hr>
                <b>Wells Spudded in Last 90 Days (reported)</b>
                <br>
            	<img src="images/bluesquare.jpg" align="top">
            	<hr>
            	<b>Lesser Prairie Chicken Crucial Habitat</b>
            	<img src="images/lepc_legend.png">
            </div>

			<div class="tab" id="linksTab" dojoType="dijit.layout.ContentPane" title="Links">
    			<p>
                <ul>
                	<li><a href="http://www.kgs.ku.edu/PRS/petroDB.html" target="_blank">Oil and Gas Database Home Page</a></li>
					<p>
                	<li><a href="http://www.kgs.ku.edu" target="_blank">KGS Home Page</a></li>
                    <p>
                    <li><a href="http://permanent.access.gpo.gov/websites/ergusgsgov/erg.usgs.gov/isb/pubs/booklets/symbols/index.html" target="_blank">Topographic Map Symbols</a></li>
                    <p>
                    <li><a href="http://maps.kgs.ku.edu/wwc5" target="_blank">KGS WWC5 Water Well Mapper</a></li>
				</ul>
            </div>
        </div>
	</div>

	<!-- Footer: -->
	<div id="bottom" dojotype="dijit.layout.ContentPane" region="bottom" style="height:23px;">
		<div id="footer">
			<div preload="true" dojoType="dijit.layout.ContentPane" id="filter_on" style="background-color:##FF0000; display:none; text-align:left; width:50%; position:fixed; left:0px">
				<span id="filter_msg" style="color:##000000;font:normal normal bold 12px Arial;padding-left:3px"></span>
				<button class="label" onClick="filterWells('off');" style="text-align:center;z-index:26">Show All Oil and Gas Wells</button>
			</div>
            <div preload="true" dojoType="dijit.layout.ContentPane" id="wwc5_filter_on" style="background-color:##00FFFF; display:none; text-align:left; width:50%; position:fixed; right:0px">
				<span id="wwc5_filter_msg" style="color:##000000;font:normal normal bold 12px Arial;padding-left:3px">WWC5</span>
				<button class="label" onClick="filterWells('wwc5_off');" style="text-align:center;z-index:26">Show All Water Wells</button>
			</div>
            <div id='junk'></div>
		</div>
	</div>
</div>

<!--- Suggestion Box: --->
<!--<div id="sb" style="position:absolute;top:77px;left:75px;background-color:yellow;border:3px solid red;text-align:center;padding:2px;font:normal normal normal 12px arial">
    <b>All comments received to date: <span id="commentcount">0</span></b><br>
    <button onClick="dijit.byId('suggestionBox').show();" style="margin:4px;">Suggestions</button>&nbsp;&nbsp;&nbsp;<button onClick="dojo.byId('sb').style.display='none';" style="margin:4px;">Close</button><br>
    What improvements could be made in the<br>
    next version of the oil and gas mapper?<br>
</div>-->

<!-- Quick zoom dialog box: -->
<div class="dialog" dojoType="dijit.Dialog" id="quickzoom" title="Zoom to Location" style="text-align:center;font:normal normal bold 14px arial">
    <table>
    <tr>
        <td class="label">Township: </td>
        <td>
            <select id="twn">
                <option value=""></option>
                <cfloop index="i" from="1" to="35">
                    <option value="#i#">#i#</option>
                </cfloop>
            </select>
        </td>
        <td class="label" style="text-align:left">South</td>
    </tr>
    <tr>
        <td class="label">Range: </td>
        <td>
            <select id="rng">
                <option value=""></option>
                <cfloop index="j" from="1" to="43">
                    <option value="#j#">#j#</option>
                </cfloop>
            </select>
        </td>
        <td class="label">East:<input type="radio" name="rng_dir" id="rng_dir_e" value="E" /> or West:<input type="radio" name="rng_dir" id="rng_dir_w" value="W" checked="checked" /></td>
    </tr>
    <tr>
        <td class="label">Section: </td>
        <td>
            <select id="sec">
                <option value=""></option>
                <cfloop index="k" from="1" to="36">
                    <option value="#k#">#k#</option>
                </cfloop>
            </select>
        </td>
    </tr>
    <tr><td></td><td><button class="label" onClick="quickZoom('plss');">Go</button></td></tr>
    </table>

	<div id="or"><img src="images/or.jpg" /></div>
    <table>
    	<tr><td class="label" align="right">Latitude: </td><td align="left"><input type="text" id="latitude" size="10" /><span class="note" style="font-weight:normal">&nbsp;(ex. 39.12345)</span></td></tr>
        <tr><td class="label" align="right">Longitude: </td><td align="left"><input type="text" id="longitude" size="10" /><span class="note" style="font-weight:normal">&nbsp;(ex. -95.12345)</span></td></tr>
        <tr><td class="label" align="right">Datum: </td><td align="left">
        	<select id="datum">
        		<option value="nad27">NAD27</option>
        		<option value="nad83">NAD83</option>
        		<option value="wgs84">WGS84</option>
        	</select>
       	<tr><td></td><td align="left"><button class="label" onclick="zoomToLatLong(dojo.byId('latitude').value,dojo.byId('longitude').value,dojo.byId('datum').value);">Go</button></td></tr>
    </table>

    <div id="or"><img src="images/or.jpg" /></div>
        <table>
        <tr><td class="label">Well API:</td><td></td><td></td><td class="note">(extension optional)</td></tr>
        <tr>
            <td><input type="text" id="api_state" size="2" onKeyUp="jumpFocus('api_county', 2, this.id)" style="height:14px"/> - </td>
            <td><input type="text" id="api_county" size="3" onKeyUp="jumpFocus('api_number', 3, this.id)" style="height:14px" /> - </td>
            <td><input type="text" id="api_number" size="5" onKeyUp="jumpFocus('api_extension', 5, this.id)" style="height:14px" /> - </td>
            <td><input type="text" id="api_extension" size="4" style="height:14px" />&nbsp;<button class="label" onClick="quickZoom('well');">Go</button></td>
        </tr>
        </table>
    <div id="or"><img src="images/or.jpg" /></div>
    <div class="input">
        <span class="label">Field Name:</span>
        <div dojoType="dojo.data.ItemFileReadStore" jsId="fieldStore" url="fields.txt"></div>
        <input id="field" dojoType="dijit.form.FilteringSelect" store="fieldStore" searchAttr="name" autocomplete="false" hasDownArrow="false"/>
        <button class="label" onClick="quickZoom('field',dojo.byId('field').value);">Go</button>
   </div>
   <div id="or"><img src="images/or.jpg" /></div>
    <div class="input">
        <span class="label">Town:</span>
        <div dojoType="dojo.data.ItemFileReadStore" jsId="fieldStore" url="towns.txt"></div>
        <input id="town" dojoType="dijit.form.FilteringSelect" store="fieldStore" searchAttr="name" autocomplete="false" hasDownArrow="false"/>
        <button class="label" onClick="quickZoom('town',dojo.byId('town').value);">Go</button>
    </div>
    <div id="or"><img src="images/or.jpg" /></div>
    <div class="input">
        <span class="label">County:</span>
        <select id="county">
            <option value="">-- Select --</option>
            <cfloop query="qCounties">
                <option value="#name#">#name#</option>
            </cfloop>
        </select>
        <button class="label" onClick="quickZoom('county',dojo.byId('county').value);">Go</button>
    </div>
    <div id="or"><img src="images/or.jpg" /></div>
    <div class="input">
    	<span class="label">Return to original location </span>
    	<button class="label" onClick="quickZoom(lastLocType, lastLocValue, 'return');">Go</button>
    </div>
    </div>
</div>

<!-- Filter menu: -->
<div dojoType="dijit.Menu" id="filterMenu" contextMenuForWindow="false" style="display: none;" targetNodeIds="filter" leftClicktoOpen="true">
	<div dojoType="dijit.MenuItem"><b>Oil and Gas Wells:</b></div>
	<div dojoType="dijit.MenuItem" onClick="filterWells('off');">Show All Wells</div>
	<div dojoType="dijit.MenuItem" onClick="filterWells('selected_field');">Show Wells Assigned to Selected Field</div>
	<div dojoType="dijit.PopupMenuItem" id="submenu2">
    	<span>Show Wells with Electric Logs</span>
        <div dojoType="dijit.Menu">
        	<div dojoType="dijit.MenuItem" onClick="filterWells('paper')">Paper</div>
        	<div dojoType="dijit.MenuItem" onClick="filterWells('scanned')">Scanned</div>
    	</div>
    </div>
    <div dojoType="dijit.MenuItem" onClick="filterWells('las');">Show Wells with LAS Files</div>
    <div dojoType="dijit.MenuItem" onClick="filterWells('cuttings');">Show Wells with Rotary Cuttings</div>
    <div dojoType="dijit.MenuItem" onClick="filterWells('cores');">Show Wells with Core Samples</div>
    <div dojoType="dijit.MenuItem" onClick="filterWells('active_well');">Show Only Active Wells</div>
	<div dojoType="dijit.MenuItem" onClick="filterWells('horiz');">Show Only Horizontal Wells</div>
    <div dojoType="dijit.MenuSeparator"></div>
    <div dojoType="dijit.MenuItem"><b>WWC5 Water Wells:</b></div>
    <div dojoType="dijit.MenuItem" onClick="filterWells('show_monitoring');">Show All Wells</div>
    <div dojoType="dijit.MenuItem" onClick="filterWells('remove_monitoring');">Remove Monitoring/Engineering Wells</div>
</div>

<!-- Label menu: -->
<div dojoType="dijit.Menu" id="labelMenu" contextMenuForWindow="false" style="display: none;" targetNodeIds="label" leftClicktoOpen="true">
	<div dojoType="dijit.MenuItem"><b>Oil and Gas Wells</b></div>
	<div dojoType="dijit.MenuItem" onClick="setVisibleWellLayer('none');">No Labels</div>
    <div dojoType="dijit.MenuItem" onClick="setVisibleWellLayer('api');">API Number</div>
	<div dojoType="dijit.MenuItem" onClick="setVisibleWellLayer('leasewell');">Well Name & Number</div>
    <div dojoType="dijit.MenuItem" onClick="setVisibleWellLayer('formation');">Producing Formation</div>
    <div dojoType="dijit.MenuItem" onClick="setVisibleWellLayer('year');">Year of Completion</div>
</div>

<!-- Warning message dialog box: -->
<div class="dialog" dojoType="dijit.Dialog" id="warning_box" title="Error" style="text-align:center;font:normal normal bold 14px arial">
	<div id="warning_msg" style="font:normal normal normal 12px Arial"></div><p>
	<button class="label" onClick="dijit.byId('warning_box').hide()">OK</button>
</div>

<!-- Download diaglog box: -->
<div class="dialog" dojoType="dijit.Dialog" id="download" title="Download Oil and Gas Well Data" style="text-align:center;font:normal normal bold 14px arial">
    <div style="font:normal normal normal 12px arial; text-align:left">
    	<ul>
        	<li>Creates comma-delimited text files with well, tops, log, LAS, cuttings, and core information for wells visible in the current map extent.</li>
            <li>If a filter is in effect, the download will also be filtered.</li>
            <li>If the <em>Show Wells Assigned to Selected Field</em> filter is on, all wells for the field will be downloaded, even if they are not visible in the current map extent.</li>
        </ul>
        <ul>
        	<li>This dialog box will close and another will open with links to your files (may take a few minutes depending on number of wells).</li>
            <li><b>You may continue to use the map while the progress indicator is displayed.</b></li>
        </ul>
        <ul>
       		<li>
        		Other options to download well data can be accessed through the <a href="http://www.kgs.ku.edu/PRS/petroDB.html" target="_blank">oil and gas well database</a>.
        	</li>
        </ul>
    </div>
    <button class="label" style="text-align:center" onClick="createDownloadFile();dijit.byId('download').hide();">Download</button>
    <button class="label" style="text-align:center" onClick="dijit.byId('download').hide();">Cancel</button>
</div>

<div class="dialog" dojoType="dijit.Dialog" id="download_results" title="Download File is Ready" style="text-align:center;font:normal normal bold 14px arial">
	<span id="download_msg"></span>
</div>

<!-- Print dialog box 2 (for new print task): -->
<div dojoType="dijit.Dialog" id="printdialog2" title="Print to PDF" style="text-align:center;font:normal normal bold 14px arial">
    <div style="font:normal normal normal 12px arial;">
    	<table align="center">
        	<tr><td style="font-weight:bold" align="right">Title (optional):</td><td align="left"><input type="text" id="pdftitle2" size="50" /></td></tr>
            <tr><td style="font-weight:bold" align="right">Orientation:</td><td align="left"><input type="radio" id="landscape2" name="pdforientation2" value="landscape" checked="checked" />Landscape&nbsp;&nbsp;&nbsp;&nbsp;<input type="radio" id="portrait2" name="pdforientation2" value="portrait" />Portrait</td></tr>
            <tr><td style="font-weight:bold" align="right">Print map only (as jpg):</td><td align="left"><input type="checkbox" id="maponly"></td></tr>
        </table>
    </div>
    <p>
    <button class="label" onclick="printPDF();" style="text-align:center">Print</button>
    <button class="label" style="text-align:center" onclick="dijit.byId('printdialog2').hide();">Cancel</button>
    <p>
    <span style="font:normal normal normal 12px arial">Note: Pop-up blockers must be turned off or set to allow pop-ups from 'maps.kgs.ku.edu'</span>
</div>

<!-- Prairie Chicken Notes dialog: -->
<div dojoType="dijit.Dialog" id="lepcnotes" title="Lesser Prairie Chicken Crucial Habitat map layer notes" style="text-align:center;font:normal normal bold 14px arial">
    <div style="text-align:left;font:normal normal normal 12px arial">
        <p>
        	The Lesser Prairie Chicken (LEPC) Crucial Habitat map layer is part of the <br>
        	Southern Great Plains Crucial Habitat Assessment Tool (SGP CHAT), produced and maintained <br>
        	by the Kansas Biological Survey. For more information, including inquiries, <br>
        	please visit the <a href="http://kars.ku.edu/geodata/maps/sgpchat" target="_blank">project website</a>.
        </p>
        <p>
        	SGP CHAT is intended to provide useful and non-regulatory information during the <br>
        	early planning stages of development projects, conservation opportunities, and environmental review.
 		</p>
 		<p>
			SGP CHAT is not intended to replace consultation with local, state, or federal agencies.
 		</p>
 		<p>
			The finest data resolution is one square mile hexagons, and use of this data layer <br>
			at a more localized scale is not appropriate and may lead to inaccurate interpretations. <br>
			The classification may or may not apply to the entire section. Consult with local <br>
			biologists for more localized information.
        </p>
    </div>
</div>

<!-- Earthquake filter dialog: -->
<div dojoType="dijit.Dialog" id="quakefilter" title="Filter Earthquakes" style="text-align:center;font:normal normal bold 14px arial">
    <div style="text-align:left;font:normal normal normal 12px arial">
        <p>
        <input type="button" onclick="filterQuakesRecent();" value="Show Last Event in Kansas" />
   		</p>
   		OR
    	<p>
        Year:&nbsp;
        <select name="year" id="year">
            <option value="all" selected>All</option>
            <option value="2016">2016</option>
            <option value="2015">2015</option>
            <option value="2014">2014</option>
            <option value="2013">2013</option>
        </select>
        &nbsp;&nbsp;
        Magnitude:&nbsp;
        <select name="mag" id="mag">
            <option value="all" selected>All</option>
            <option value="2">2.0+</option>
            <option value="3">3.0+</option>
            <option value="4">4.0+</option>
        </select>
        &nbsp;&nbsp;
        <input type="button" onclick="filterQuakes(dojo.byId('year').value,dojo.byId('mag').value);" value="Go" />
        </p>
        <p>
        OR
        </p>
        <p>
        Show all earthquakes &nbsp;
        <select name="days" id="days">
            <option value="7" selected>in the last week</option>
            <option value="14">in the last two weeks</option></option>
            <option value="30">in the last month</option>
            <option value="all">since 2013</option>
        </select>
        &nbsp;&nbsp;
        <input type="button" onclick="filterQuakesDays(dojo.byId('days').value)" value="Go" />
        </p>
        <p>
        <input type="button" onclick="clearQuakeFilter()" value="Reset" />
        </p>
    </div>
</div>

<!-- Earthquake Notes dialog: -->
<div dojoType="dijit.Dialog" id="quakenotes" title="Earthquake Data Notes" style="text-align:center;font:normal normal bold 14px arial">
    <div style="text-align:left;font:normal normal normal 12px arial">
        <p>Data for all events occurring between 1/9/2013 and 3/7/2014 was provided by the Oklahoma Geological Survey - all<br>
        other data is from the USGS.
        </p>
        <p>
        Earthquake data for Oklahoma is incomplete and only extends back to 12/2/2014. Only events occurring in northern Oklahoma<br>
        (north of Medford) are included on the mapper.
    	</p>
    </div>
</div>

<!-- Suggestion Box: -->
<div dojoType="dijit.Dialog" id="suggestionBox" title="Suggestions" style="text-align:center;font:normal normal bold 14px arial">
    <div style="text-align:left;font:normal normal normal 14px arial">
        <p>
            The KGS is beginning a long-term redesign of its web mappers to make them more accessible on mobile devices. <br>
            New features are planned as part of that redesign and we'd like your input. Please enter brief descriptions of any <br>
            new tools, features, and map layers you'd like to see in the next version.
        </p>
        <p>
            <p>
                Map Layers:<br>
                <input type="text" id="layers" name="layers" size="125">
            </p>
            <p>
                Tools and Features:<br>
                <input type="text" id="tools" name="tools" size="125">
            </p>
            <p>
                General Comments:<br>
                <textarea id="comments" name="comments" rows="4" cols="90"></textarea>
            </p>
            <p>
                Please tell us about your occupation (industry, government, researcher, general public, etc.):<br>
                <input type="text" id="occupation" name="tools" size="125">
            </p>
            <p>
            <button onclick="submitComments(dojo.byId('layers').value, dojo.byId('tools').value, dojo.byId('comments').value, dojo.byId('occupation').value);">Submit</button> - Thank you!
            </p>
        </p>
    </div>
</div>


<!-- Download loading indicator: -->
<div id="loading_div" style="display:none; position:relative; z-index:1000;">
    <img id="loading" src="images/loading.gif" />
</div>

<!-- Printing indicator: -->
<div id="printing_div" style="display:none; position:absolute; top:50px; left:500px; z-index:1000;">
    <img id="loading" src="images/ajax-loader.gif" />
</div>

<script type="text/javascript">
var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
</script>
<script type="text/javascript">
var pageTracker = _gat._getTracker("UA-1277453-7");
pageTracker._trackPageview();
</script>

</body>
</html>
</cfoutput>

