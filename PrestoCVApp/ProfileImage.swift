//
//  ProfileImage.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 27/02/2020.
//  Copyright © 2020 Giovanni Trovato. All rights reserved.
//

import SwiftUI

struct ProfileImage: View {
    var body: some View {
        VStack(alignment: .center) {
            Image("Image")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100, alignment: .center)
            
            
            
            Button(action: {
                
            }) {
                Text(/*@START_MENU_TOKEN@*/"Button"/*@END_MENU_TOKEN@*/)
            }
            .padding(.top, -37.0)
            .background(Color.red)
        }
            
        .clipShape(Circle())
        .shadow(radius: 10)
        .overlay(Circle()
        .stroke(Color.gray, lineWidth: 1))
    }
}

struct ProfileImage_Previews: PreviewProvider {
    static var previews: some View {
        ProfileImage()
    }
}
