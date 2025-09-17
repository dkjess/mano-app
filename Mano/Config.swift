//
//  Config.swift
//  Mano
//
//  Created by Jess Wambui Olsen on 31/08/2025.
//

import Foundation

struct Config {
    #if DEBUG
    // Using ngrok tunnel for device testing - change back to localhost for simulator
    static let supabaseURL = "https://77f0216c6f2b.ngrok-free.app"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
    #else
    static let supabaseURL = "https://zfroutbzdkhivnpiezho.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpmcm91dGJ6ZGtoaXZucGllemhvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk0MTY3MTAsImV4cCI6MjA2NDk5MjcxMH0.1oPaalBGxcVx1cOu_E4k8WVJIxL2OsS45bwPrbjnBt4"
    #endif
}