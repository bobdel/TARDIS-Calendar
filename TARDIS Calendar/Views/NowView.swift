//
//  NowView.swift
//  TARDIS Calendar
//
//  Created by Monty Harper on 10/13/23.
//

import Foundation
import SwiftUI

struct NowView: View {
    
    // For now I'm disabling the detail view; I may decide I don't need it.
    // Will need feedback from my mom to know for sure!
    @State private var detailView = false
    
    var body: some View {
        
        // TODO: - this is hard-wired for now. Will need to allow user to specify an image and retrieve it here from user defaults. Also need to provide an alternative image as a default.
        
        let image = Settings.shared.userImage
        
        Group {
            
//            if detailView {
//
//                Circle()
//                    .frame(width: 250, height: 250)
//                    .foregroundColor(.yellow)
//                    .shadow(color: .white, radius: 20)
//                    .opacity(0.70)
//                    .overlay(
//                        VStack {
//                            Text("Next activity: working on this")
//
//                        }
//                    )
//                    .clipShape(ContainerRelativeShape()).padding()
//
//            }
//            else {
                
            ArrowView(size: 100.0)
                .zIndex(-90)
            Circle().frame(width: 100, height: 100).foregroundColor(.yellow).shadow(color: .white, radius: 20)
            image.resizable().aspectRatio(contentMode:.fit).frame(width:90, height:90, alignment:.center).clipShape(Circle())
                
            }
//        }
//       .onTapGesture(perform: {detailView.toggle()})
        
    }
}





