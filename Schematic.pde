import org.gicentre.utils.spatial.*;

/**
 * Animates a route from a map to a strip map and back when you click the mouse
 * Press enter to take a screenshot
 */

/* Settings */
final float LERP_INTERVAL = 0.2  ;            // the transition speed (0 = never, 1 = instantly) 
final int ROUTE_WEIGHT = 2;                   // the line weight in px for the route (and turns on the strip map)
final int STRIP_WEIGHT = 1;                   // the line weight in px for the strip map 
final color LINE_COLOUR =  color(0);          // the desired rgb(a) colour for the line
final color ELLIPSE_COLOUR = color(0);        // the desired rgb(a) colour for the line
final int BUFFER = 40;                        // the size of the empty bit at the very top and bottom of the screen
final String COLUMN = "Talent Number change"; // the column to size the results by
final int ELLIPSE_MIN = 12;                   // the minimum diameter of a station
final int ELLIPSE_MAX = 36;                   // the maximum diameter of a station
final int MIN_COLOUR = color(219, 22, 60);    //the colour for the minimum value
final int MAX_COLOUR = color(0, 152, 212);    //the colour for the maximum value

/* Globals */
boolean TO_STRIP = false;          //this controls the direction of the animation
ArrayList<PVector> geoRoute;       //route in geo coords
ArrayList<PVector> screenRoute;    //route in screen coords
ArrayList<PVector> animatedRoute;  //this is the one that actually moves - in screen coords
ArrayList<PVector> strip;          //target strip in screen coords
ArrayList<Float> column;           //the data with which stations will be styled
PVector tlCorner;                  //top left corner of the sketch
PVector brCorner;                  //bottom right corner of the sketch
float strokeWeight = ROUTE_WEIGHT; //the stroke weight for the line
PImage northArrow;                 //the north arrow
float transparency;                //keeps track of background / north arrow transparency
float colMin = Float.MAX_VALUE;    //stores the lowest value in the dataset
float colMax = Float.MIN_VALUE;    //stores the highest value in the dataset
PImage backgroundMap;              //the background map

/**
 * Load and process route data and bg map
 */
void setup() {

  //setup environment
  size(700, 700);  //**the dimensions must be reflected by the data in geotoscreen
  background(255);
  stroke(LINE_COLOUR);
  //smooth(8);  //extra antialiasing - Can be useful for retina displays
  frameRate(30);
  
  backgroundMap = loadImage("map.png");
  //backgroundMap.filter(GRAY);  //grayscale your background map if required
  
  //load the North arrow
  northArrow = loadImage("north.png");

  //set up projection and map bounds (must be same shape as in size() and the background map)
  OSGB proj = new OSGB();
  tlCorner = new PVector(524420.264, 190626.751);
  brCorner = new PVector(540660.264, 174386.751);

  //load into PVector Array
  geoRoute = new ArrayList<PVector>();
  screenRoute = new ArrayList<PVector>();
  animatedRoute = new ArrayList<PVector>();
  strip = new ArrayList<PVector>();
  column = new ArrayList<Float>();

  //read in input data
  Table table = loadTable("stations.csv", "header");
  for (TableRow row : table.rows()) {
    PVector node = proj.transformCoords(new PVector(row.getFloat("X"), row.getFloat("Y")));
    geoRoute.add(node);                    //in geo coords
    screenRoute.add(geoToScreen(node));    //in screen coords
    animatedRoute.add(geoToScreen(node));  //the version that will actually be adjusted
    column.add(row.getFloat(COLUMN));
    if(row.getFloat(COLUMN) < colMin) colMin = row.getFloat(COLUMN);
    if(row.getFloat(COLUMN) > colMax) colMax = row.getFloat(COLUMN);
  }

  //draw the route onto the screen, whilst calculating the cumulative distance
  float[] distances = new float[geoRoute.size()];
  distances[0] = 0;  //distance to the origin is always 0...
  float cumulativeDistance = 0;
  for (int j = 1; j < geoRoute.size (); j++) {

    //convert to screen coords
    PVector previous = screenRoute.get(j-1);
    PVector current = screenRoute.get(j); 

    //calculate cumulative distance in m and store in array
    cumulativeDistance += sqrt(pow(geoRoute.get(j).x - geoRoute.get(j-1).x, 2) + pow(geoRoute.get(j).y - geoRoute.get(j-1).y, 2));
    distances[j] = cumulativeDistance;
  }

  //make the distances into a 1d set of coordinates along the strip map
  float newX = width / 2;
  for (int k = 0; k < geoRoute.size (); k++) {
    strip.add(new PVector(newX, map(distances[k], 0, cumulativeDistance, BUFFER, height - BUFFER)));
  }
}

/**
 * Draw the route and handle the animation
 */
void draw() {
  //reset bg
  background(255);

  //draw the actual route (or strip)
  if (TO_STRIP) {  //route to strip

    //fade bgmap out
    transparency = (transparency > 0.001) ? transparency - (200 * LERP_INTERVAL) : 0; 
    tint(255, transparency);
    image(backgroundMap, 0, 0, width, height);
    image(northArrow, 10, 10);

    //set the stroke width
    strokeWeight = (strokeWeight < STRIP_WEIGHT) ? strokeWeight + ((STRIP_WEIGHT - ROUTE_WEIGHT) * LERP_INTERVAL) : STRIP_WEIGHT;
    strokeWeight(strokeWeight);

    //dynamically straighten route into strip map
    for (int l = 0; l < screenRoute.size (); l++) {

      //lerp towards the strip
      animatedRoute.get(l).lerp(strip.get(l), LERP_INTERVAL);

      //convert to screen coords and draw
      if (l > 0) {
        PVector previous = animatedRoute.get(l-1);
        PVector current = animatedRoute.get(l); 
        line(previous.x, previous.y, current.x, current.y);
      }
    }
  } else {  //strip to route

    //fade bgmap in
    transparency = (transparency < 180) ? transparency + (200 * LERP_INTERVAL) : 180; 
    tint(255, transparency);
    image(backgroundMap, 0, 0, width, height);
    image(northArrow, 10, 10);

    //set the stroke width
    strokeWeight = (strokeWeight > ROUTE_WEIGHT) ? strokeWeight - ((STRIP_WEIGHT - ROUTE_WEIGHT) * LERP_INTERVAL) : ROUTE_WEIGHT;
    strokeWeight(strokeWeight);

    //dynamically shift strip back to route
    for (int l = 0; l < screenRoute.size (); l++) {

      //lerp towards the strip
      animatedRoute.get(l).lerp(screenRoute.get(l), LERP_INTERVAL);

      //convert to screen coords and draw
      if (l > 0) {
        PVector previous = animatedRoute.get(l-1);
        PVector current = animatedRoute.get(l); 
        line(previous.x, previous.y, current.x, current.y);
      }
    }
  }

  //draw the station ellipses in
  stroke(ELLIPSE_COLOUR);
  strokeWeight(1);
  for (int l = 0; l < animatedRoute.size (); l++) {
      fill(lerpColor(MIN_COLOUR, MAX_COLOUR, map(column.get(l), colMin, colMax, 0, 1)));
      int ellipseSize = floor(map(column.get(l), colMin, colMax, ELLIPSE_MIN, ELLIPSE_MAX));
      ellipse(animatedRoute.get(l).x, animatedRoute.get(l).y, ellipseSize, ellipseSize);
  }
  stroke(LINE_COLOUR);
  strokeWeight(ROUTE_WEIGHT);
}


/**
 * Change the direction of the transform when the mouse is clicked
 */
void mousePressed() {
  TO_STRIP = (TO_STRIP) ? false : true;
}


/**
 * Take a screenshot if someone presses spacebar
 */
void keyPressed() {
  if (key == ENTER || key == RETURN) {
    println("screenshot taken");
    save("screenshot.png");
  }
}


/**
 * Convert geo coordinates to screen coordinates
 */
PVector geoToScreen(PVector geo)
{
  return new PVector(map(geo.x, tlCorner.x, brCorner.x, 0, width), 
    map(geo.y, tlCorner.y, brCorner.y, 0, height));
}

/**
 * Work out the distance between two PVectors
 */
float distance(PVector from, PVector to) {
  return sqrt(pow(from.x - to.x, 2) + pow(from.y - to.y, 2));
}

/**
 * Get the bearing in degrees between two PVectors
 */
float direction(PVector from, PVector to) {
  return (90 - (atan2(to.y - from.y, to.x - from.x) / PI * 180) + 360) % 360;
}

/**
 * Offset a 2D PVector by a given distance and direction 
 */
PVector pointOffset(PVector point, float distance, float azimuth) {
  //simple geometric offset in each dimension
  int x = floor(point.x + sin(radians(azimuth)) * distance);
  int y = floor(point.y - cos(radians(azimuth)) * distance);  // Use '-' because we're working in pixels not metres
  return new PVector(x, y);
}