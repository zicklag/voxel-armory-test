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
import armory.trait.physics.bullet.PhysicsWorld;
import armory.trait.physics.bullet.RigidBody;

import kha.input.Mouse;
import kha.input.Keyboard;
import kha.input.KeyCode;

using GameMain.VoxelExtensions;

class VoxelExtensions {
	static public function getTransform(voxel:Voxel):Transform {
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

		generateVoxelMesh(voxels);
	}

	function init() {
		// Spawn voxel chunk
		spawnVoxelMesh();
	}

	function onMouseDown(button: Int, x: Int, y: Int) {
		var clickRay = RayCaster.getRay(x, y, Scene.active.camera);
		// var closestTransform = RayCaster.closestBoxIntersect(transforms, x, y, Scene.active.camera);

		// For every voxel check whether or not the ray intersects any of them
		var newVoxels = [];
		for (voxel in this.voxels) {
			var t = voxel.getTransform();
			if (!clickRay.intersectsBox(t.loc, t.dim)) {
				newVoxels.push(voxel);
			}
		}

		this.voxels = newVoxels;
		generateVoxelMesh(this.voxels);
		spawnVoxelMesh();
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

	function generateVoxelMesh(voxels:Array<Voxel>) {
		// Re-generate Voxel Mesh
		var voxelMesh:Array<Triangle> = VoxelTools.newVoxelMesh(voxels);

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
}
