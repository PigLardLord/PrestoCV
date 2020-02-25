//
//  ContentView.swift
//  PrestoCVApp
//
//  Created by Giovanni Trovato on 24/02/2020.
//  Copyright © 2020 pigLardLord. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Image("AppIcon")
        .resizable()
            .aspectRatio(contentMode: .fill)
        .frame(width: 250.0, height: 250.0, alignment: .center)
        .clipShape(Circle())

        
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
