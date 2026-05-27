# Build App Android Bang Expo EAS

File nay huong dan build `apps/mobile` ra Android APK/AAB. App mobile cua repo dung Expo SDK 54, Expo Router, React Native.

## 1. APK va AAB khac nhau the nao?

| Dinh dang | Dung khi nao |
|---|---|
| APK | Cai truc tiep len dien thoai/emulator de test |
| AAB | Upload len Google Play Store |

Neu ban chi can gui file cho thay/co ban be test, build APK.

Neu ban muon phat hanh len Google Play, build AAB.

## 2. Chuan bi tai khoan va cong cu

Can co:

- Node.js 20 hoac moi hon.
- Tai khoan Expo.
- Backend production HTTPS, vi du `https://api.example.com`.
- Android phone hoac Android Emulator.

Cai EAS CLI:

```bash
npm install -g eas-cli
```

Dang nhap:

```bash
eas login
eas whoami
```

## 3. Kiem tra app config

File `apps/mobile/app.json` hien co:

```json
{
  "expo": {
    "name": "ChatApp",
    "slug": "chat-app-mobile",
    "android": {
      "package": "com.chatapp.mobile",
      "permissions": ["android.permission.RECORD_AUDIO"]
    }
  }
}
```

Truoc khi release that, nen doi:

- `name`: ten hien thi app.
- `slug`: ten project Expo.
- `android.package`: package duy nhat, vi du `com.yourteam.binchat`.

Can quy tac:

- `android.package` khong duoc trung app khac tren Google Play.
- Nen quyet dinh som vi doi package sau nay rat phien.

## 4. Tao file `.env` cho mobile

Trong `apps/mobile`, tao file:

```bash
cd apps/mobile
nano .env
```

Noi dung:

```env
EXPO_PUBLIC_API_URL=https://api.example.com
EXPO_PUBLIC_SOCKET_URL=https://api.example.com
```

Kiem tra trong source:

- API dung `EXPO_PUBLIC_API_URL`.
- Socket mobile dung `getApiUrl()`, nen production can `EXPO_PUBLIC_API_URL`.

## 5. Cau hinh EAS lan dau

Tu thu muc mobile:

```bash
cd apps/mobile
eas build:configure
```

Lenh nay se tao/cap nhat `eas.json`.

Neu chua co `eas.json`, tao noi dung nay:

```json
{
  "cli": {
    "version": ">= 13.0.0"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "android": {
        "buildType": "apk"
      },
      "env": {
        "EXPO_PUBLIC_API_URL": "https://api.example.com",
        "EXPO_PUBLIC_SOCKET_URL": "https://api.example.com"
      }
    },
    "preview": {
      "distribution": "internal",
      "android": {
        "buildType": "apk"
      },
      "env": {
        "EXPO_PUBLIC_API_URL": "https://api.example.com",
        "EXPO_PUBLIC_SOCKET_URL": "https://api.example.com"
      }
    },
    "production": {
      "android": {
        "buildType": "app-bundle"
      },
      "env": {
        "EXPO_PUBLIC_API_URL": "https://api.example.com",
        "EXPO_PUBLIC_SOCKET_URL": "https://api.example.com"
      }
    }
  }
}
```

Ghi chu:

- `preview` tao APK de cai truc tiep.
- `production` tao AAB de upload Google Play.

## 6. Build APK de test tren dien thoai

Chay:

```bash
cd apps/mobile
eas build --platform android --profile preview
```

Lan dau EAS co the hoi:

- Co muon tao Android keystore khong?
- Chon de Expo tu quan ly credentials neu ban moi bat dau.

Sau khi build xong, EAS in ra link. Mo link do tren dien thoai Android va tai APK.

Neu Android chan cai app:

1. Mo Settings.
2. Tim `Install unknown apps`.
3. Cho phep trinh duyet/file manager cai APK.
4. Cai lai APK.

## 7. Cai APK bang adb

Neu dung Android Emulator hoac phone cam cap USB:

```bash
adb devices
adb install path/to/app.apk
```

Neu da cai ban cu:

```bash
adb install -r path/to/app.apk
```

Neu bi loi signature/package:

```bash
adb uninstall com.chatapp.mobile
adb install path/to/app.apk
```

## 8. Build AAB de upload Google Play

Chay:

```bash
cd apps/mobile
eas build --platform android --profile production
```

Ket qua la file `.aab`.

Google Play yeu cau tai khoan Google Play Developer, hien thuong co phi dang ky mot lan. Sau khi co AAB:

1. Vao Google Play Console.
2. Tao app moi.
3. Khai bao app name, language, app/game.
4. Vao `Testing` hoac `Production`.
5. Tao release.
6. Upload `.aab`.
7. Dien release notes.
8. Hoan thanh cac muc policy/content rating/data safety.
9. Submit review.

## 9. Build Android tu GitHub Actions

Doc [CI_CD_GITHUB_ACTIONS.md](./CI_CD_GITHUB_ACTIONS.md), phan `Workflow trigger Android EAS Build`.

Tom tat:

1. Tao `EXPO_TOKEN`.
2. Them vao GitHub Secrets.
3. Tao workflow dung `expo/expo-github-action`.
4. Chay:

```yaml
eas build --platform android --profile preview --non-interactive --no-wait
```

Quan trong: Phai build thanh cong 1 lan tren may local truoc, de EAS tao project ID va credentials.

## 10. Test app sau khi cai

Checklist:

- Mo app khong crash.
- Dang ky/dang nhap duoc.
- Refresh app van giu session.
- Chat realtime duoc.
- Upload anh/audio duoc.
- Voice message ghi am duoc, vi app co permission `RECORD_AUDIO`.
- Goi audio/video neu co TURN server.
- `@bot` tra loi neu AI service/OpenAI key OK.

## 11. Loi thuong gap

### 11.1 App goi nham localhost

Trong production build, `localhost` la chinh dien thoai, khong phai server.

Kiem tra:

```env
EXPO_PUBLIC_API_URL=https://api.example.com
```

Neu build roi moi sua `.env`, phai build lai. Bien `EXPO_PUBLIC_*` duoc bundle vao app khi build.

### 11.2 Network request failed

Kiem tra:

- `https://api.example.com/api/health` mo duoc tren trinh duyet dien thoai.
- SSL hop le.
- Backend CORS co cho mobile origin khong. Mobile native khong bi CORS nhu browser, nhung cookie/API van can backend dung.
- EC2 Security Group mo 443.

### 11.3 Socket khong realtime

Kiem tra:

- Mobile socket dang dung `getApiUrl()`.
- `EXPO_PUBLIC_API_URL` la HTTPS backend.
- Server Caddy reverse proxy `/socket.io` ve gateway.
- Gateway Socket.IO dang chay.

### 11.4 Build fail vi package name

Kiem tra `android.package` trong `app.json`.

Dung format:

```txt
com.company.appname
```

Khong dung dau gach ngang, khong viet hoa.

### 11.5 Build fail vi dependency Expo

Chay:

```bash
cd apps/mobile
npx expo doctor
```

Neu Expo de xuat version package, sua theo huong dan.

## 12. Build local khong dung EAS co nen khong?

Co the, nhung khong khuyen nghi cho nguoi moi vi phai cai Android Studio, JDK, Gradle, Android SDK.

Neu van muon:

```bash
cd apps/mobile
npx expo prebuild
cd android
./gradlew assembleRelease
```

Tren Windows:

```powershell
cd apps/mobile
npx expo prebuild
cd android
.\gradlew.bat assembleRelease
```

APK se nam trong:

```txt
android/app/build/outputs/apk/release/
```

Nhung voi repo nay, EAS la cach de hon va it loi moi truong hon.

## 13. Nguon tham khao

- EAS Build setup: https://docs.expo.dev/build/setup/
- Build APK: https://docs.expo.dev/build-reference/apk
- EAS Build on CI: https://docs.expo.dev/build/building-on-ci/
- Android build process: https://docs.expo.dev/build-reference/android-builds/
