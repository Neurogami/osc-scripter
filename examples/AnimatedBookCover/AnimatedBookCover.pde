import animata.*;

import animata.model.Skeleton.*;
import animata.model.Layer;

import processing.opengl.*;

import java.util.Iterator;
import java.util.Map;

import java.util.Collections;
import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.Arrays;


int animationLoop  = 1;
int ANIMATE_ON_COUNT = 3;

int animationCounter = 0;
int maxAnimationLoop = 5;

HashMap sceneTable = new HashMap();
HashMap mainCharacterScenes = new HashMap();

String mainSceneName = "osc-for-artists";

AnimataP5 mainScene;

// Adding this, and having it return true, makes your sketch fullscree, no window borders.
// It's set to false for demo purposes
boolean sketchFullScreen() {
//  return true;
  return false;
}


//-----------------------------------------------------------
void setup() {
  size(508, 738, OPENGL);
  loadScene(mainSceneName);
  mainScene = (AnimataP5) sceneTable.get(mainSceneName);
  loadData();
  setupOsc();
}

//-----------------------------------------------------------
void draw() {
  background(255);
  mainScene.draw(0,0);
}
