package com.studyapp.presentation.scanner

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Camera
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

private const val TAG = "BarcodeScannerScreen"

object BarcodeTypes {
    const val ISBN = 5
    const val EAN_13 = 4
    const val EAN_8 = 14
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BarcodeScannerScreen(
    onBarcodeScanned: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    
    var hasCameraPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED
        )
    }
    
    var scannedBarcode by remember { mutableStateOf<String?>(null) }
    var isScanning by remember { mutableStateOf(true) }
    var scanError by remember { mutableStateOf<String?>(null) }
    var isProcessing by remember { mutableStateOf(false) }
    
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        hasCameraPermission = isGranted
    }
    
    LaunchedEffect(Unit) {
        if (!hasCameraPermission) {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        text = "バーコードスキャン",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                ),
                navigationIcon = {
                    IconButton(onClick = onDismiss) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "戻る",
                            tint = MaterialTheme.colorScheme.onPrimary
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (hasCameraPermission && isScanning) {
                CameraPreview(
                    onBarcodeDetected = { barcode ->
                        if (!isProcessing && scannedBarcode == null) {
                            isProcessing = true
                            scannedBarcode = barcode
                            isScanning = false
                            onBarcodeScanned(barcode)
                        }
                    },
                    onError = { error ->
                        Log.e(TAG, "Scan error", error)
                        scanError = error.message
                    },
                    isScanning = { isScanning }
                )
                
                ScanningOverlay()
            } else if (!hasCameraPermission) {
                NoPermissionContent(
                    onRequestPermission = {
                        permissionLauncher.launch(Manifest.permission.CAMERA)
                    }
                )
            }
            
            if (scannedBarcode != null) {
                ScannedResultOverlay(
                    barcode = scannedBarcode!!,
                    onRescan = {
                        scannedBarcode = null
                        isScanning = true
                        isProcessing = false
                    },
                    onConfirm = {
                        onBarcodeScanned(scannedBarcode!!)
                    }
                )
            }
            
            scanError?.let { error ->
                Snackbar(
                    modifier = Modifier.padding(16.dp),
                    containerColor = MaterialTheme.colorScheme.error
                ) {
                    Text("エラー: $error")
                }
            }
        }
    }
}

@Composable
private fun CameraPreview(
    onBarcodeDetected: (String) -> Unit,
    onError: (Exception) -> Unit,
    isScanning: () -> Boolean
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    
    val cameraProviderFuture = remember {
        ProcessCameraProvider.getInstance(context)
    }
    
    val executor = remember { Executors.newSingleThreadExecutor() }
    
    val scanner = remember { BarcodeScanning.getClient() }
    
    DisposableEffect(Unit) {
        onDispose {
            executor.shutdown()
            scanner.close()
        }
    }
    
    AndroidView(
        factory = { ctx ->
            val previewView = PreviewView(ctx)
            
            cameraProviderFuture.addListener({
                val cameraProvider = cameraProviderFuture.get()
                
                val preview = Preview.Builder()
                    .build()
                    .also {
                        it.setSurfaceProvider(previewView.surfaceProvider)
                    }
                
                val imageAnalyzer = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also { analysis ->
                        analysis.setAnalyzer(executor) { imageProxy ->
                            processImageProxy(
                                imageProxy = imageProxy,
                                scanner = scanner,
                                isScanning = isScanning,
                                onBarcodeDetected = onBarcodeDetected,
                                onError = onError
                            )
                        }
                    }
                
                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                
                try {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        lifecycleOwner,
                        cameraSelector,
                        preview,
                        imageAnalyzer
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Camera binding failed", e)
                    onError(e)
                }
            }, ContextCompat.getMainExecutor(ctx))
            
            previewView
        },
        modifier = Modifier.fillMaxSize()
    )
}

@androidx.annotation.OptIn(markerClass = [ExperimentalGetImage::class])
private fun processImageProxy(
    imageProxy: ImageProxy,
    scanner: BarcodeScanner,
    isScanning: () -> Boolean,
    onBarcodeDetected: (String) -> Unit,
    onError: (Exception) -> Unit
) {
    val mediaImage = imageProxy.image
    if (mediaImage == null) {
        imageProxy.close()
        return
    }
    
    val inputImage = InputImage.fromMediaImage(
        mediaImage,
        imageProxy.imageInfo.rotationDegrees
    )
    
    scanner.process(inputImage)
        .addOnSuccessListener { barcodes ->
            if (isScanning()) {
                for (barcode in barcodes) {
                    when (barcode.valueType) {
                        BarcodeTypes.ISBN,
                        BarcodeTypes.EAN_13,
                        BarcodeTypes.EAN_8 -> {
                            barcode.rawValue?.let { value ->
                                onBarcodeDetected(value)
                                return@addOnSuccessListener
                            }
                        }
                    }
                }
            }
        }
        .addOnFailureListener { exception ->
            Log.e(TAG, "Barcode scanning failed", exception)
            onError(exception)
        }
        .addOnCompleteListener {
            imageProxy.close()
        }
}

@Composable
private fun ScanningOverlay() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.3f)),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(
                modifier = Modifier
                    .size(250.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.Transparent)
            )
            
            Spacer(modifier = Modifier.height(24.dp))
            
            Text(
                text = "バーコードを枠内に合わせてください",
                color = Color.White,
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(horizontal = 32.dp)
                    .background(
                        Color.Black.copy(alpha = 0.5f),
                        RoundedCornerShape(8.dp)
                    )
                    .padding(12.dp)
            )
        }
    }
}

@Composable
private fun ScannedResultOverlay(
    barcode: String,
    onRescan: () -> Unit,
    onConfirm: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.7f)),
        contentAlignment = Alignment.Center
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(32.dp),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    imageVector = androidx.compose.material.icons.Icons.Default.Check,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(64.dp)
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                Text(
                    text = "バーコードを検出しました",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text(
                    text = barcode,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Spacer(modifier = Modifier.height(24.dp))
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedButton(
                        onClick = onRescan,
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("再スキャン")
                    }
                    
                    Button(
                        onClick = onConfirm,
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("このISBNで検索")
                    }
                }
            }
        }
    }
}

@Composable
private fun NoPermissionContent(
    onRequestPermission: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = androidx.compose.material.icons.Icons.Default.Camera,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(64.dp)
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "カメラの許可が必要です",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "バーコードをスキャンするにはカメラへのアクセスを許可してください",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Button(onClick = onRequestPermission) {
            Text("許可する")
        }
    }
}
