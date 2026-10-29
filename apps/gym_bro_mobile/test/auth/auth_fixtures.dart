// Response bodies for the auth endpoints (apps/gym_bro_api/supabase/functions/
// users/index.ts), shaped like a real POST /users/signin from the local stack
// (tokens replaced, the Supabase `user` object trimmed).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gym_bro_mobile/l10n/app_localizations.dart';

/// The `profile` returned next to the session (SAFE_COLUMNS of `users`).
Map<String, dynamic> profileJson({
  String id = '8d0b05de-7c18-441b-9536-aaa042eaeaaa',
  String username = 'liamoconnor',
  String email = 'liam.oconnor@example.com',
  String name = 'Liam',
  String lastName = "O'Connor",
  String role = 'member',
  String? avatarUrl = 'https://api.dicebear.com/9.x/avataaars/png?seed=liamoconnor&size=256',
}) =>
    {
      'id': id,
      'username': username,
      'email': email,
      'name': name,
      'last_name': lastName,
      'role': role,
      'avatar_url': avatarUrl,
      'auth_id': '774941e4-d9e1-4097-9e3d-823aaa9ba6a3',
      'created_at': '2026-09-15T16:05:42.372Z',
      'updated_at': '2026-10-28T18:40:23.199Z',
    };

/// A Supabase Auth session (`/token` grant response).
Map<String, dynamic> sessionJson({
  String accessToken = 'access-1',
  String refreshToken = 'refresh-1',
  int expiresIn = 3600,
}) =>
    {
      'access_token': accessToken,
      'token_type': 'bearer',
      'expires_in': expiresIn,
      'expires_at': 1793216765,
      'refresh_token': refreshToken,
      'user': {
        'id': '774941e4-d9e1-4097-9e3d-823aaa9ba6a3',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'liam.oconnor@example.com',
        'app_metadata': {'provider': 'email', 'providers': ['email']},
        'user_metadata': {'username': 'liamoconnor', 'name': 'Liam', 'last_name': "O'Connor"},
        'is_anonymous': false,
      },
      'weak_password': null,
    };

/// POST /users/signin, /users/verify-invite, /users/google: `{...session, profile}`.
Map<String, dynamic> signinJson({
  String accessToken = 'access-1',
  String refreshToken = 'refresh-1',
  int expiresIn = 3600,
  Map<String, dynamic>? profile,
}) =>
    {
      ...sessionJson(accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn),
      'profile': profile ?? profileJson(),
    };

/// A route that marks where navigation ended up.
Widget placeholder(String name) => Scaffold(body: Center(child: Text('<$name>')));

/// Same localizations as lib/main.dart.
const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
