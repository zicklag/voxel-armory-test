package arm;

import kex.vox.VoxelTools;
import kex.vox.Voxel;
import kex.vox.Triangle;
import kex.vox.MeshFactory;

import iron.Scene;
import iron.data.SceneFormat;
import iron.data.MeshData;
import iron.data.MaterialData;
import iron.data.Data;
import iron.object.Transform;
import iron.object.MeshObject;
import iron.system.Input;
import iron.math.Vec4;
import iron.math.RayCaster;
import iron.math.Ray;
import armory.trait.physics.bullet.PhysicsWorld;
import armory.trait.physics.bullet.RigidBody;

import kha.input.Mouse;
import kha.input.Keyboard;
import kha.input.KeyCode;

using GameMain.VoxelExtensions;

class VoxelExtensions {
	static public function getTransform(voxel:Voxel):Transform {
		if (voxel == null) {return null;}
		var t = new Transform(null);
		t.loc = new Vec4(voxel.x, voxel.y, voxel.z);
		t.dim = new Vec4(1, 1, 1);
		return t;
	}
}

class GameMain extends iron.Trait {
	var meshData:MeshData;
	var meshObject:MeshObject;
	var voxels:Array<Voxel> = new Array();
	var blockTransforms:Array<Transform>;
	var materials:haxe.ds.Vector<MaterialData>;
 	
	public function new() {
		super();

		// Set mouse event listeners
		notifyOnInit(function() {
			Mouse.get().notify(onMouseDown, onMouseUp, onMouseMove, onMouseWheel);
			Keyboard.get().notify(onKeyDown, onKeyUp);
		});

		notifyOnRemove(function() {
			// Trait or its object is removed, remove event listeners
			Mouse.get().remove(onMouseDown, onMouseUp, onMouseMove, onMouseWheel);
			Keyboard.get().remove(onKeyDown, onKeyUp, null);
		});

		// Create array of voxels
		this.voxels = [
			{x:0, y:0, z:0, color: {r:256,g:0,b:256,a:256}},
			{x:0, y:1, z:0, color: {r:256,g:0,b:256,a:256}},
			{x:0, y:3, z:0, color: {r:256,g:0,b:256,a:256}},
			{x:-1, y:2, z:0, color: {r:256,g:0,b:256,a:256}},
			{x:1, y:2, z:0, color: {r:256,g:0,b:256,a:256}},
			{x:-3, y:2, z:2, color: {r:256,g:0,b:256,a:256}},
			{x:-3, y:2, z:1, color: {r:256,g:0,b:256,a:256}},
			{x:3, y:2, z:1, color: {r:256,g:0,b:256,a:256}},
		];

		generateVoxelMesh();
	}

	function init() {
		// Spawn voxel chunk
		spawnVoxelMesh();
	}

	function onMouseDown(button: Int, x: Int, y: Int) {
		if (button == 0) {
			breakBlockUnderMouse(x, y);
		} else if (button == 1) {
			placeBlockUnderMouse(x, y);
		}
	}

	function onMouseUp(button: Int, x: Int, y: Int) { }
	function onMouseMove(x: Int, y: Int, movementX: Int, movementY: Int) { }
	function onMouseWheel(delta: Int) { }

	function onKeyDown(key:KeyCode) {

		function handleSpacebar() {
			trace("Spacebar");
		}

		switch (key) {
			case Space: handleSpacebar();
			default:
		}
	}

	function onKeyUp(key:KeyCode) {}

	function generateVoxelMesh() {
		// Re-generate Voxel Mesh
		var voxelMesh:Array<Triangle> = VoxelTools.newVoxelMesh(this.voxels);

		// Generate new Iron Mesh Data
		var ironMesh:TMeshData = MeshFactory.createRawIronMeshData(voxelMesh, "KexIronMesh", 0, 0, 0);

		// Remove existing voxel mesh
		if (this.meshObject != null) {
			Scene.active.meshes.remove(this.meshObject);
			this.meshData.delete();
		}

		// Update Mesh Data instance
		new MeshData(ironMesh, function(data:MeshData) {
			// Assign loaded MeshData
			this.meshData = data;
			// Calculate bounding box
			this.meshData.geom.calculateAABB();

			if (this.materials == null) {
				// Load Material From scene
				Data.getMaterial("Scene", "DefaultBlockMat", function(data:MaterialData) {
					this.materials = haxe.ds.Vector.fromData([data]);
					notifyOnInit(init);
				});
			}
		});
	}

	function spawnVoxelMesh() {
		// Re-spawn new voxel mesh
		this.meshObject = Scene.active.addMeshObject(meshData, materials);
	}

	function breakBlockUnderMouse(x:Int, y:Int) {
		this.voxels.remove(getVoxelUnderMouse(x,y));

		generateVoxelMesh();
		spawnVoxelMesh();
	}

	function placeBlockUnderMouse(x:Int, y:Int) {
		var clickRay = RayCaster.getRay(x, y, Scene.active.camera);
		var clickedVoxel = getVoxelUnderMouse(x,y);
		if (clickedVoxel == null) {return;}
		var t = clickedVoxel.getTransform();
		var clickLoc = clickRay.intersectBox(t.loc, t.dim);

		var placementRay = new Ray(clickLoc, Scene.active.camera.transform.loc);
		var placementPos = placementRay.at(0.01);
		var newVoxel = {
			x: Math.round(placementPos.x),
			y: Math.round(placementPos.y),
			z: Math.round(placementPos.z),
			color: {r:256,g:0,b:256,a:256}
		}

		this.voxels.push(cast newVoxel);
		generateVoxelMesh();
		spawnVoxelMesh();
	}

	function getVoxelUnderMouse(mouseX:Int, mouseY:Int) {
		var clickRay = RayCaster.getRay(mouseX, mouseY, Scene.active.camera);
		var closest:Voxel = null;

		// Get blocks under mouse click
		var intersections = [];
		for (voxel in this.voxels) {
			var t = voxel.getTransform();
			if (clickRay.intersectsBox(t.loc, t.dim)) {
				intersections.push(voxel);
			}
		}

		// Get closest block to mouse click
		if (intersections.length != 0) {
			var minDist:Float = std.Math.POSITIVE_INFINITY;
			for (voxel in intersections) {
				var dist = Vec4.distance(voxel.getTransform().loc, Scene.active.camera.transform.loc);
				if (dist < minDist) {
					minDist = dist;
					closest = voxel;
				}
			}
		}

		return closest;
	}
}
