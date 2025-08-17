//
//  ContentView.swift
//  PrestoCV
//
//  Created by Giovanni Trovato on 30/11/21.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Text(LocalizedString("common.hello.world"))
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
