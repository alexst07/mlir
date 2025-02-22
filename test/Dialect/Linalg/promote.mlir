// RUN: mlir-opt %s -linalg-promote-subviews | FileCheck %s
// RUN: mlir-opt %s -linalg-promote-subviews -test-linalg-promote-dynamic | FileCheck %s --check-prefix=DYNAMIC

#map0 = (d0, d1)[s0, s1] -> (d0 * s1 + s0 + d1)
#map1 = (d0) -> (d0 + 2)
#map2 = (d0) -> (d0 + 4)
#map3 = (d0) -> (d0 + 3)

// CHECK-DAG: #[[strided2D:.*]] = (d0, d1)[s0, s1] -> (d0 * s1 + s0 + d1)
// CHECK-DAG: #[[strided2DnoOffset:.*]] = (d0, d1)[s0] -> (d0 * s0 + d1)

module {
  func @matmul(%A: memref<?xi8>, %M: index, %N: index, %K: index) {
    %c4 = constant 4 : index
    %c3 = constant 3 : index
    %c2 = constant 2 : index
    %c0 = constant 0 : index
    %c1 = constant 1 : index
    %3 = view %A[%M, %K][%c0] : memref<?xi8> to memref<?x?xf32, #map0>
    %4 = view %A[%K, %N][%c0] : memref<?xi8> to memref<?x?xf32, #map0>
    %5 = view %A[%M, %N][%c0] : memref<?xi8> to memref<?x?xf32, #map0>
    %6 = dim %3, 0 : memref<?x?xf32, #map0>
    %7 = dim %3, 1 : memref<?x?xf32, #map0>
    %8 = dim %4, 1 : memref<?x?xf32, #map0>
    loop.for %arg4 = %c0 to %6 step %c2 {
      loop.for %arg5 = %c0 to %8 step %c3 {
        loop.for %arg6 = %c0 to %7 step %c4 {
          %9 = affine.apply #map1(%arg4)
          %10 = affine.apply #map2(%arg6)
          %11 = linalg.subview %3[%arg4, %9, %c1, %arg6, %10, %c1] : memref<?x?xf32, #map0>
          %12 = affine.apply #map2(%arg6)
          %13 = affine.apply #map3(%arg5)
          %14 = linalg.subview %4[%arg6, %12, %c1, %arg5, %13, %c1] : memref<?x?xf32, #map0>
          %15 = affine.apply #map1(%arg4)
          %16 = affine.apply #map3(%arg5)
          %17 = linalg.subview %5[%arg4, %15, %c1, %arg5, %16, %c1] : memref<?x?xf32, #map0>
          linalg.matmul(%11, %14, %17) : memref<?x?xf32, #map0>, memref<?x?xf32, #map0>, memref<?x?xf32, #map0>
        }
      }
    }
    return
  }
}

// CHECK-LABEL: func @matmul(%{{.*}}: memref<?xi8>, %{{.*}}: index, %{{.*}}: index, %{{.*}}: index) {
//       CHECK:   loop.for %{{.*}} = %{{.*}} to %{{.*}} step %{{.*}} {
//       CHECK:     loop.for %{{.*}} = %{{.*}} to %{{.*}} step %{{.*}} {
//       CHECK:       loop.for %{{.*}} = %{{.*}} to %{{.*}} step %{{.*}} {
//       CHECK:         %[[vA:.*]] = linalg.subview {{.*}} : memref<?x?xf32, #[[strided2D]]>
//       CHECK:         %[[vB:.*]] = linalg.subview {{.*}} : memref<?x?xf32, #[[strided2D]]>
//       CHECK:         %[[vC:.*]] = linalg.subview {{.*}} : memref<?x?xf32, #[[strided2D]]>
///
//       CHECK:         %[[tmpA:.*]] = alloc() : memref<32xi8>
//       CHECK:         %[[fullA:.*]] = std.view %[[tmpA]][][{{.*}}] : memref<32xi8> to memref<?x?xf32>
//     DYNAMIC:         std.view %{{.*}}[][{{.*}}] : memref<?xi8> to memref<?x?xf32>
//       CHECK:         %[[partialA:.*]] = linalg.slice %[[fullA]][%{{.*}}, %{{.*}}] : memref<?x?xf32>, !linalg.range, !linalg.range, memref<?x?xf32, #[[strided2DnoOffset]]>
///
//       CHECK:         %[[tmpB:.*]] = alloc() : memref<48xi8>
//       CHECK:         %[[fullB:.*]] = std.view %[[tmpB]][][{{.*}}] : memref<48xi8> to memref<?x?xf32>
//     DYNAMIC:         std.view %{{.*}}[][{{.*}}] : memref<?xi8> to memref<?x?xf32>
//       CHECK:         %[[partialB:.*]] = linalg.slice %[[fullB]][%{{.*}}, %{{.*}}] : memref<?x?xf32>, !linalg.range, !linalg.range, memref<?x?xf32, #[[strided2DnoOffset]]>
///
//       CHECK:         %[[tmpC:.*]] = alloc() : memref<24xi8>
//       CHECK:         %[[fullC:.*]] = std.view %[[tmpC]][][{{.*}}] : memref<24xi8> to memref<?x?xf32>
//     DYNAMIC:         std.view %{{.*}}[][{{.*}}] : memref<?xi8> to memref<?x?xf32>
//       CHECK:         %[[partialC:.*]] = linalg.slice %[[fullC]][%{{.*}}, %{{.*}}] : memref<?x?xf32>, !linalg.range, !linalg.range, memref<?x?xf32, #[[strided2DnoOffset]]>

//       CHECK:         linalg.fill(%[[fullA]], {{.*}}) : memref<?x?xf32>, f32
//       CHECK:         linalg.fill(%[[fullB]], {{.*}}) : memref<?x?xf32>, f32
//       CHECK:         linalg.fill(%[[fullC]], {{.*}}) : memref<?x?xf32>, f32
//       CHECK:         linalg.copy(%[[vA]], %[[partialA]]) : memref<?x?xf32, #[[strided2D]]>, memref<?x?xf32, #[[strided2DnoOffset]]>
//       CHECK:         linalg.copy(%[[vB]], %[[partialB]]) : memref<?x?xf32, #[[strided2D]]>, memref<?x?xf32, #[[strided2DnoOffset]]>
//       CHECK:         linalg.copy(%[[vC]], %[[partialC]]) : memref<?x?xf32, #[[strided2D]]>, memref<?x?xf32, #[[strided2DnoOffset]]>
//
//       CHECK:         linalg.matmul(%[[fullA]], %[[fullB]], %[[fullC]]) : memref<?x?xf32>, memref<?x?xf32>, memref<?x?xf32>
//
//       CHECK:         linalg.copy(%[[partialC]], %[[vC]]) : memref<?x?xf32, #[[strided2DnoOffset]]>, memref<?x?xf32, #[[strided2D]]>
//
//       CHECK:         dealloc %[[tmpA]] : memref<32xi8>
//       CHECK:         dealloc %[[tmpB]] : memref<48xi8>
//       CHECK:         dealloc %[[tmpC]] : memref<24xi8>
