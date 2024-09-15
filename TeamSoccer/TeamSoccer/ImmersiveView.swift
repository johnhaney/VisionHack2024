//
//  ImmersiveView.swift
//  TeamSoccer
//
//  Created by John Haney on 9/13/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @PhysicalMetric(wrappedValue: 1, from: .meters) var oneMeter
    
    let MIN_TOSS_RADIUS: Double = 1
    let MIN_TOSS_RADIUS_SQUARED: Double = 1

    var startPosition = Entity()
    
    @State var pose: Pose3D?
    @State private var cancellables = [EventSubscription]()
    
    let targetNames: [String] = ["A", "B", "C", "D", "E"]
    @State var targets: [String: ModelEntity] = [:]
    @State var selectedTarget: String?

    var body: some View {
        RealityView { content in
            startPosition.position = .init(x: 0, y: 1.5, z: -1.5)
            content.add(startPosition)
            let one: ModelEntity
            do {
                let mesh = MeshResource.generateBox(width: 0.85, height: 1.1, depth: 0.01)
                one = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .orange, isMetallic: false)])
                one.collision = CollisionComponent(shapes: [ShapeResource.generateBox(width: 0.85, height: 1.1, depth: 0.01)])
                startPosition.addChild(one)
                one.components.set(InputTargetComponent())
            }
            let updateEvent = content.subscribe(to: SceneEvents.Update.self, { event in
                //                    let deltaTime = Float(event.deltaTime)
                if let pose {
                    one.pose = pose
                }
                for (name, entity) in targets {
                    if let materials = entity.model?.materials {
                        if name == selectedTarget {
                            if materials.count == 1 {
                                entity.model?.materials = [
                                    SimpleMaterial(color: .white, isMetallic: false),
                                    materials[0]
                                ]
                            }
                        } else if materials.count > 1 {
                            entity.model?.materials = [materials.last].compactMap({ $0 })
                        }
                    }
                }
            })
                cancellables.append(updateEvent)
            let mesh = MeshResource.generateCylinder(height: 0.01, radius: 0.3)
            var hue = 0.1
            for target in targetNames {
                let entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: UIColor(hue: hue, saturation: 0.8, brightness: 0.8, alpha: 1), isMetallic: false)])
                let RADIUS = MIN_TOSS_RADIUS * 3
                let angle = (-hue / 2) - 0.25
                entity.transform.translation = SIMD3<Float>(x: Float(RADIUS * cos(.pi * angle)), y: 0, z: Float(RADIUS * sin(.pi * angle)))
                hue += 0.2
                content.add(entity)
                targets[target] = entity
            }
        }
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .targetedToAnyEntity()
            .onChanged({ drag in
                self.pose = Pose3D(position: Point3D((1.0 / oneMeter) * drag.translation3D), rotation: .identity)
                let endVector = drag.predictedEndTranslation3D
                if endVector.x * endVector.x + endVector.z * endVector.z > MIN_TOSS_RADIUS_SQUARED {
                    print("square distance: \(endVector.x * endVector.x + endVector.z * endVector.z)")
                    let angle = atan2(endVector.z, endVector.x) / .pi
                    var hue = -2 * (angle + 0.25)
                    if hue < 0 {
                        hue += 2
                    }
                    if hue >= 1 {
                        hue -= 2
                    }
//                    print("hue: \(hue), angle: \(angle) [\(endVector.x),\(endVector.z)]")
                    if 0 <= hue,
                       hue <= 1 {
                        let index = Int(round((hue + 0.1)/0.2))
                        if index >= 1,
                           index < targetNames.count {
                            selectedTarget = targetNames[index - 1]
                        }
                    } else {
                        if hue > -0.1 {
                            selectedTarget = targetNames.first
                        } else if hue < 1.1 {
                            selectedTarget = targetNames.last
                        }
                    }
                }
            })
            .onEnded({ drag in
                selectedTarget = nil
            })
        )
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}

extension Entity {
    var pose: Pose3D {
        set {
            self.position = SIMD3<Float>(newValue.position)
            self.transform.rotation = simd_quatf(newValue.rotation)
        }
        get {
            .identity
        }
    }
}
