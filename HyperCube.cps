/**
  HyperCube CAM post processor for Fusion360
  Compatible with Marlin 1.1.4+

  By Tech2C
  https://www.thingiverse.com/thing:1752766
  https://www.youtube.com/watch?v=n2jM6v3E7sU&list=PLIaArjwViQRVAERWRrYfe9rtiwvvRGCzw

  Adapted from 'Generic Grbl' (grbl.cps) and 'Dumper' (dump.cps)
*/
description = "HyperCube for Fusion360";
vendor = "Marlin";
vendorUrl = "https://github.com/MarlinFirmware/Marlin";

extension = "gcode";
setCodePage("ascii");

capabilities = CAPABILITY_INTERMEDIATE;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

// user-defined properties
properties = {
  startPositionZ: "2",
  finishHome: true,
  finishBeep: false,
  rapidTravelXY: 2500,
  rapidTravelZ: 300,
  laserEtch: "M106 S128",
  laserVaperize: "M106 S255",
  laserThrough: "M106 S192",
  laserOFF: "M107"
};

var xyzFormat = createFormat({decimals:3});
var feedFormat = createFormat({decimals:0});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var planeOutput = createVariable({prefix:"G"}, feedFormat);

// circular output
var	iOutput	= createReferenceVariable({prefix:"I"}, xyzFormat);
var	jOutput	= createReferenceVariable({prefix:"J"}, xyzFormat);
var	kOutput	= createReferenceVariable({prefix:"K"}, xyzFormat);

var cuttingMode;

function formatComment(text) {
  return String(text).replace(/[\(\)]/g, "");
}

function writeComment(text) {
  writeWords(formatComment(text));
}

function onOpen() {
  writeln(";***********************************************************************************");
  writeln(";HyperCube CAM post processor for Fusion360: Version 1.0");
  writeln(";Compatible with Marlin 1.1.4+");
  writeln(";By Tech2C");
  writeln(";https://www.thingiverse.com/thing:1752766");
  writeln(";https://www.youtube.com/watch?v=n2jM6v3E7sU&list=PLIaArjwViQRVAERWRrYfe9rtiwvvRGCzw");
  writeln(";***********************************************************************************");
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of X, Y, Z, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

function onSection() {
  if(isFirstSection()) {
    writeln("");
	writeWords("M117 Starting...");
	writeWords(properties.laserOFF, "         ;Laser/Fan OFF");
    writeWords("G21", "          ;Metric Values");
	writeWords(planeOutput.format(17), "          ;Plane XY");
	writeWords("G90", "          ;Absolute Positioning");
	writeWords("G92 X0 Y0 Z0", " ;Set XYZ Positions");
	writeWords("G0", feedOutput.format(properties.rapidTravelXY));
	if(properties.startPositionZ) { writeWords("G0 Z" + properties.startPositionZ, feedOutput.format(properties.rapidTravelZ), "   ;Position Z"); }
}
  
  if (currentSection.getType() == TYPE_JET) {
    if(currentSection.jetMode == 0) {cuttingMode = properties.laserThrough }
	else if(currentSection.jetMode == 1) {cuttingMode = properties.laserEtch }
	else if(currentSection.jetMode == 2) {cuttingMode = properties.laserVaperize }
	else {cuttingMode = (properties.laserOFF + "         ;Unknown Laser Cutting Mode") }
  }
  
  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
	  writeln("");
	  writeWords("M400");
      writeComment("M117 " + comment);
    }
  }
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.001, seconds, 99999.999);
  writeWords("G4 S" + seconds, "        ;Dwell time");
}

function onPower(power) {
  if (power) { writeWords(cuttingMode) }
  else { writeWords(properties.laserOFF) }
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y) {
    writeWords("G0", x, y, feedOutput.format(properties.rapidTravelXY));
  }
  if (z) {
    writeWords("G0", z, feedOutput.format(properties.rapidTravelZ));
  }
}

function onLinear(_x, _y, _z, _feed) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(_feed);
  if(x || y || z) {
    writeWords("G1", x, y, z, f);
  }
  else if (f) {
    writeWords("G1", f);
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  // one of X/Y and I/J are required and likewise
  var start = getCurrentPosition();
  
  switch (getCircularPlane()) {
  case PLANE_XY:
    writeWords(planeOutput.format(17), (clockwise ? "G2":"G3"), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
    break;
  case PLANE_ZX:
    writeWords(planeOutput.format(18), (clockwise ? "G2":"G3"), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
    break;
  case PLANE_YZ:
    writeWords(planeOutput.format(19), (clockwise ? "G2":"G3"), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
	break;
  default:
    linearize(tolerance);
  }
}

function onSectionEnd() {
  writeWords(planeOutput.format(17));
  forceAny();
}

function onClose() {
  writeln("");
  writeWords("M400");
  writeWords(properties.laserOFF, "         ;Laser/Fan OFF");
  writeWords("G0", feedOutput.format(properties.rapidTravelXY));
  if(properties.finishHome) {
    writeWords("G0", xOutput.format(0), yOutput.format(0), zOutput.format(0), feedOutput.format(properties.rapidTravelXY));
  }
  writeWords("M84", "          ;Motors OFF");
  if(properties.finishBeep) { writeWords("M300 S800 P300"); }
  writeWords("M117 Finished :)");
}
