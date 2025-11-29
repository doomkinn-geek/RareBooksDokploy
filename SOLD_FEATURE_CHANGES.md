# Добавление функционала продажи книг - Изменения

## Backend

### UserCollectionService.cs

#### Обновить метод `UpdateBookAsync`:
```csharp
book.IsSold = request.IsSold;
book.SoldPrice = request.SoldPrice;
book.SoldDate = request.SoldDate;
```

#### Обновить метод `GetStatisticsAsync`:
```csharp
var booksNotSold = books.Where(b => !b.IsSold).ToList();
var booksSold = books.Where(b => b.IsSold).ToList();

var stats = new CollectionStatisticsDto
{
    TotalBooks = books.Count,
    BooksSold = booksSold.Count,
    BooksInCollection = booksNotSold.Count,
    TotalEstimatedValue = booksNotSold.Where(b => b.EstimatedPrice.HasValue)
                              .Sum(b => b.EstimatedPrice.Value),
    TotalPurchaseValue = books.Where(b => b.PurchasePrice.HasValue)
                              .Sum(b => b.PurchasePrice.Value),
    TotalSoldValue = booksSold.Where(b => b.SoldPrice.HasValue)
                          .Sum(b => b.SoldPrice.Value),
    // ...
};

// Расчёт прибыли
stats.TotalProfit = stats.TotalSoldValue - booksSold.Where(b => b.PurchasePrice.HasValue)
                                                     .Sum(b => b.PurchasePrice.Value);
```

#### Обновить метод `MapToDto`:
```csharp
IsSold = book.IsSold,
SoldPrice = book.SoldPrice,
SoldDate = book.SoldDate,
```

#### Обновить метод `GetBookDetailsAsync`:
```csharp
IsSold = book.IsSold,
SoldPrice = book.SoldPrice,
SoldDate = book.SoldDate,
```

## Frontend

### CollectionBookDetail.jsx

#### State формы:
```jsx
const [formData, setFormData] = useState({
    // ... existing fields
    isSold: false,
    soldPrice: '',
    soldDate: ''
});
```

#### В loadBook:
```jsx
isSold: bookData.isSold || false,
soldPrice: bookData.soldPrice || '',
soldDate: bookData.soldDate ? bookData.soldDate.split('T')[0] : ''
```

#### В handleUpdate:
```jsx
isSold: formData.isSold,
soldPrice: formData.soldPrice ? parseFloat(formData.soldPrice) : null,
soldDate: formData.soldDate || null
```

#### UI в форме (после purchase fields):
```jsx
<Grid item xs={12}>
    <Typography variant="h6" gutterBottom sx={{ mt: 2 }}>
        Информация о продаже
    </Typography>
</Grid>

<Grid item xs={12}>
    <FormControlLabel
        control={
            <Switch
                checked={formData.isSold}
                onChange={(e) => setFormData({ ...formData, isSold: e.target.checked })}
            />
        }
        label="Книга продана"
    />
</Grid>

{formData.isSold && (
    <>
        <Grid item xs={12} sm={6}>
            <TextField
                label="Цена продажи"
                name="soldPrice"
                type="number"
                value={formData.soldPrice}
                onChange={(e) => setFormData({ ...formData, soldPrice: e.target.value })}
                fullWidth
                InputProps={{
                    startAdornment: <Box component="span" sx={{ mr: 1 }}>₽</Box>,
                }}
            />
        </Grid>

        <Grid item xs={12} sm={6}>
            <TextField
                label="Дата продажи"
                name="soldDate"
                type="date"
                value={formData.soldDate}
                onChange={(e) => setFormData({ ...formData, soldDate: e.target.value })}
                fullWidth
                InputLabelProps={{ shrink: true }}
            />
        </Grid>
    </>
)}
```

### UserCollection.jsx

#### Обновить статистику:
```jsx
<Grid item xs={12} sm={6} md={2.4}>
    <Typography variant="h4" sx={{ fontWeight: 'bold' }}>
        {statistics.totalPurchaseValue.toLocaleString()} ₽
    </Typography>
    <Typography variant="body2">Затрачено</Typography>
</Grid>

<Grid item xs={12} sm={6} md={2.4}>
    <Typography variant="h4" sx={{ fontWeight: 'bold' }}>
        {statistics.totalEstimatedValue.toLocaleString()} ₽
    </Typography>
    <Typography variant="body2">Оценка коллекции</Typography>
</Grid>

<Grid item xs={12} sm={6} md={2.4}>
    <Typography variant="h4" sx={{ fontWeight: 'bold' }}>
        {statistics.totalSoldValue.toLocaleString()} ₽
    </Typography>
    <Typography variant="body2">Продано ({statistics.booksSold})</Typography>
</Grid>

<Grid item xs={12} sm={6} md={2.4}>
    <Typography variant="h4" sx={{ fontWeight: 'bold', color: statistics.totalProfit >= 0 ? '#4caf50' : '#ff5252' }}>
        {statistics.totalProfit >= 0 ? '+' : ''}{statistics.totalProfit.toLocaleString()} ₽
    </Typography>
    <Typography variant="body2">Прибыль</Typography>
</Grid>

<Grid item xs={12} sm={12} md={2.4}>
    <Typography variant="h4" sx={{ fontWeight: 'bold' }}>
        {statistics.booksInCollection}
    </Typography>
    <Typography variant="body2">Книг в коллекции</Typography>
</Grid>
```

### Home.jsx

Ссылка "Моя коллекция" должна отображаться всегда, но быть disabled если нет доступа:

```jsx
{user && (user.hasCollectionAccess || user.HasCollectionAccess) && (
    <Paper ... onClick={() => navigate('/collection')}>
        ...
    </Paper>
)}
```

Или сделать так, чтобы блок всегда показывался, но был неактивным если нет доступа.

